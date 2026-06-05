#pragma once
// generator.hpp — 生成-评估闭环（09 §2.7 generate-and-test + §4 投票 + §6 筛选）。
// 流程：造候选盘面 → 求解器组评估(地板/天花板) → 按 LFHC 深度筛
//       → 自动把目标分定在「地板失败、天花板通过」的甜区 → 产出带难度标签的关卡库。
#include "solver.hpp"

namespace me {

struct GenConfig {
    int w = 8, h = 8;
    std::vector<int> species = {0, 1, 2, 3, 4, 5};
    int move_limit = 16;
    int trials = 4;           // 每个候选评估的重复次数（应对随机补充）
    double min_gap = 0.10;    // 最低 LFHC 深度（gap 太小=怎么玩都一样 → 弃）
    double frac_lo = 0.35;    // 目标落点下界（floor..ceil 之间）
    double frac_hi = 0.85;    // 目标落点上界
    double collect_ratio = 0.3;  // 约多少比例发 COLLECT 目标
    double jelly_ratio = 0.2;    // 约多少比例发 CLEAR_JELLY 目标
    double blocker_ratio = 0.2;  // 约多少比例发 CLEAR_BLOCKER 目标（其余 SCORE）
    double min_collect = 4.0;    // 某色被天花板平均收集 >= 此值才可作 COLLECT
    double min_jelly = 4.0;      // 天花板平均清果冻 >= 此值才可作 JELLY
    double coat_density = 0.18;  // 冰/锁关里涂层格占比
    int min_blocker = 3;         // 涂层格数 >= 此值才可作 BLOCKER
    double choco_density = 0.10; // 巧克力关里初始巧克力格占普通棋子格比例（0.08~0.12 甜区）
    int min_choco = 3;           // 初始巧克力格数 >= 此值才可作 CLEAR_CHOCO
    uint32_t base_seed = 1;
};

struct GeneratedLevel {
    Level level;               // 含已定好的 target_score
    double floor_score = 0;    // random 玩家原始均分（地板）
    double ceil_score = 0;     // greedy 玩家原始均分（天花板）
    double lfhc_gap = 0;       // (ceil-floor)/floor
    double skilled_pass = 0;   // 定目标后技巧玩家通过率
    double rhythm = 0;         // 局内节奏(前松后紧)评分，09 §3.6
    const char* difficulty = "?";
};

// 跑生成-评估闭环，产出最多 count 个达标关卡（最多尝试 max_attempts 次）。
inline std::vector<GeneratedLevel> generate_and_test(const GenConfig& cfg, int count, int max_attempts) {
    std::vector<GeneratedLevel> out;
    std::mt19937 boardgen(cfg.base_seed);
    std::mt19937 fracgen(cfg.base_seed ^ 0x00abcdefu);
    std::uniform_real_distribution<double> fracdist(cfg.frac_lo, cfg.frac_hi);
    const int BIG = 1 << 30;
    int attempts = 0;
    while ((int)out.size() < count && attempts < max_attempts) {
        ++attempts;
        Grid board = make_board(cfg.w, cfg.h, cfg.species, boardgen);
        uint32_t cand_seed = cfg.base_seed + (uint32_t)attempts * 7919u;

        // 满果冻层（playable=1, WALL=0）——白挂着测各玩家清多少层（不影响分/步）
        int H = (int)board.size();
        int W = (int)board[0].size();
        std::vector<std::vector<int>> full_jelly(H, std::vector<int>(W, 1));
        for (int y = 0; y < H; ++y)
            for (int x = 0; x < W; ++x)
                if (board[y][x] == WALL) full_jelly[y][x] = 0;

        // raw 评估：target 设很大 → 走满步 → 测地板/天花板的分、各色收集、果冻清层
        double fsum = 0, csum = 0, gj = 0, rj = 0;
        std::vector<double> g_col, r_col;
        for (int t = 0; t < cfg.trials; ++t) {
            Level lv;
            lv.init_board = board;
            lv.species = cfg.species;
            lv.move_limit = cfg.move_limit;
            lv.target_score = BIG;
            lv.seed = cand_seed + (uint32_t)t * 1000003u;
            lv.jelly = full_jelly;
            PlayResult rp = random_play(lv);
            PlayResult gp = greedy_play(lv);
            fsum += rp.score;
            csum += gp.score;
            rj += rp.jelly_cleared;
            gj += gp.jelly_cleared;
            if (r_col.size() < rp.collected.size()) r_col.resize(rp.collected.size(), 0.0);
            for (size_t i = 0; i < rp.collected.size(); ++i) r_col[i] += rp.collected[i];
            if (g_col.size() < gp.collected.size()) g_col.resize(gp.collected.size(), 0.0);
            for (size_t i = 0; i < gp.collected.size(); ++i) g_col[i] += gp.collected[i];
        }
        double floor_s = fsum / cfg.trials;
        double ceil_s = csum / cfg.trials;
        double g_jelly = gj / cfg.trials;
        double r_jelly = rj / cfg.trials;
        if (floor_s < 1.0) continue;
        double gap = (ceil_s - floor_s) / floor_s;
        if (gap < cfg.min_gap) continue;  // 没深度 → 弃
        for (double& v : g_col) v /= cfg.trials;
        for (double& v : r_col) v /= cfg.trials;

        Level final;
        final.init_board = board;
        final.species = cfg.species;
        final.move_limit = cfg.move_limit;
        final.seed = cand_seed;

        // 三选一：COLLECT / JELLY / SCORE（u 选型，frac 定甜区位置）
        double u = fracdist(fracgen);
        double frac = fracdist(fracgen);
        bool decided = false;
        if (u < cfg.collect_ratio) {  // 收集某色
            int best_s = -1;
            double best_gap = 0.0;
            for (size_t s = 0; s < g_col.size(); ++s) {
                if (g_col[s] < cfg.min_collect) continue;
                double rp = (s < r_col.size()) ? r_col[s] : 0.0;
                double d = g_col[s] - rp;
                if (d > best_gap) { best_gap = d; best_s = (int)s; }
            }
            if (best_s >= 0) {
                // 目标导向标定：用 smart_greedy 真去追这个目标，量它实际能收多少（而非刷分顺带量 g_col）
                double gd = 0.0;
                for (int t = 0; t < cfg.trials; ++t) {
                    Level probe;
                    probe.init_board = board;
                    probe.species = cfg.species;
                    probe.move_limit = cfg.move_limit;
                    probe.seed = cand_seed + (uint32_t)t * 1000003u;
                    probe.objectives = {{OBJ_COLLECT, best_s, BIG}};  // 大目标 → 走满步、全力追
                    PlayResult sp = smart_greedy_play(probe);
                    gd += (best_s < (int)sp.collected.size()) ? sp.collected[best_s] : 0;
                }
                gd /= cfg.trials;
                double rp = (best_s < (int)r_col.size()) ? r_col[best_s] : 0.0;
                if (gd < rp) gd = rp;  // 安全：目标导向天花板不应低于随机地板
                double ct = rp + frac * (gd - rp);
                final.objectives = {{OBJ_COLLECT, best_s, (int)(ct < 1 ? 1 : ct)}};
                decided = true;
            }
        }
        if (!decided && u < cfg.collect_ratio + cfg.jelly_ratio && g_jelly >= cfg.min_jelly) {  // 清果冻
            // 目标导向标定：smart_greedy 全力清果冻，量它能清多少层（而非刷分顺带量 g_jelly）
            double gd = 0.0;
            for (int t = 0; t < cfg.trials; ++t) {
                Level probe;
                probe.init_board = board;
                probe.species = cfg.species;
                probe.move_limit = cfg.move_limit;
                probe.seed = cand_seed + (uint32_t)t * 1000003u;
                probe.jelly = full_jelly;
                probe.objectives = {{OBJ_CLEAR_JELLY, -1, BIG}};
                PlayResult sp = smart_greedy_play(probe);
                gd += sp.jelly_cleared;
            }
            gd /= cfg.trials;
            if (gd < r_jelly) gd = r_jelly;
            int ct = (int)(r_jelly + frac * (gd - r_jelly));
            if (ct < 1) ct = 1;
            final.jelly = full_jelly;
            final.objectives = {{OBJ_CLEAR_JELLY, -1, ct}};
            decided = true;
        }
        if (!decided && u < cfg.collect_ratio + cfg.jelly_ratio + cfg.blocker_ratio) {  // 冰/锁
            std::mt19937 layoutrng(cand_seed ^ 0x5bd1e995u);
            std::uniform_real_distribution<double> dd(0.0, 1.0);
            std::vector<std::vector<int>> coat(H, std::vector<int>(W, 0));
            int total = 0;
            for (int y = 0; y < H; ++y)
                for (int x = 0; x < W; ++x)
                    if (board[y][x] != WALL && dd(layoutrng) < cfg.coat_density) {
                        coat[y][x] = 1;
                        total++;
                    }
            if (total >= cfg.min_blocker && has_legal_move(board, &coat)) {
                int ct = (int)(frac * total);
                if (ct < 1) ct = 1;
                final.coat = coat;
                final.objectives = {{OBJ_CLEAR_BLOCKER, -1, ct}};
                decided = true;
            }
        }
        if (!decided) {  // 冲分
            int target = (int)(floor_s + frac * (ceil_s - floor_s));
            if (target <= (int)floor_s) target = (int)floor_s + 1;
            final.target_score = target;
        }
        LevelEval fe = evaluate_level(final, cfg.trials);
        // 目标关的"可解性"：目标感知天花板多次一次都赢不了 → 不可解，丢掉
        if (fe.skilled_pass_rate <= 0.0) continue;

        // 局内节奏（精炼版）：量"能推进目标的交换数"曲线（目标关随障碍耗尽前松后紧）
        double rhythm = rhythm_quality(objective_progress_curve(final));

        GeneratedLevel gl;
        gl.level = final;
        gl.floor_score = floor_s;
        gl.ceil_score = ceil_s;
        gl.lfhc_gap = gap;
        gl.skilled_pass = fe.skilled_pass_rate;
        gl.rhythm = rhythm;
        gl.difficulty = fe.difficulty;
        out.push_back(gl);
    }
    return out;
}

// ---- 定向难度生成：二分搜索目标值，把 skilled_pass 逼进请求难度带 ----

// 按密度随机生成布尔掩码（异形墙/涂层共用）。seed 决定布局，density 决定占比。
inline std::vector<std::vector<char>> _mask_from(uint32_t seed, double density, int W, int H) {
    std::mt19937 r(seed);
    std::uniform_real_distribution<double> d(0.0, 1.0);
    std::vector<std::vector<char>> m(H, std::vector<char>(W, 0));
    for (int y = 0; y < H; ++y)
        for (int x = 0; x < W; ++x)
            if (d(r) < density) m[y][x] = 1;
    return m;
}

struct DiffBand {
    const char* name;
    double pl, ph;  // skilled_pass 落入 [pl, ph] 即该难度
};
inline DiffBand band_easy() { return {"EASY", 0.8, 1.01}; }
inline DiffBand band_medium() { return {"MEDIUM", 0.4, 0.8}; }
inline DiffBand band_hard() { return {"HARD", 0.1, 0.4}; }
inline DiffBand band_expert() { return {"EXPERT", 0.02, 0.1}; }

// 设置关卡的"难度旋钮"：无目标→分数线；有目标→目标数。
inline void set_level_target(Level& lv, int t) {
    if (lv.objectives.empty())
        lv.target_score = t;
    else
        lv.objectives[0].target = t;
}

// ---- 滚动/挖矿关生成（难度旋钮=步数：feed 深度固定，步多→易挖穿→skilled_pass 单调↑→可二分）----
struct ScrollConfig {
    int w = 8, h = 8;
    std::vector<int> species = {0, 1, 2, 3, 4, 5};
    int depth_pages = 4;       // feed 深度(页)，1 页 = h 行；一开始只见首页，往下约 depth_pages 页
    int trials = 6;            // 评估重复次数（feed 固定，变 reshuffle/挖穿后随机流以测稳健）
    uint32_t base_seed = 1;
};

// 造一关滚动关：初盘(无开局消除+有合法步) + 每列 depth_pages*h 格预设 feed(长盘深层内容)。
inline Level make_scroll_level(const ScrollConfig& cfg, int move_limit, uint32_t seed) {
    Level lv;
    lv.species = cfg.species;
    lv.move_limit = move_limit;
    lv.seed = seed;
    lv.is_scrolling = true;
    std::mt19937 rng(seed);
    lv.init_board = make_board(cfg.w, cfg.h, cfg.species, rng);
    int depth = cfg.depth_pages * cfg.h;
    std::uniform_int_distribution<int> dist(0, (int)cfg.species.size() - 1);
    lv.feed.assign(cfg.w, {});
    for (int x = 0; x < cfg.w; ++x)
        for (int i = 0; i < depth; ++i)
            lv.feed[x].push_back(cfg.species[dist(rng)]);
    return lv;
}

// 按难度带产滚动关：二分 move_limit，使技巧玩家"挖穿率"落入 band，取最贴带中心者。
inline GeneratedLevel generate_scroll_for_difficulty(const ScrollConfig& cfg, DiffBand band, uint32_t seed) {
    int lo = 1, hi = cfg.depth_pages * cfg.h * 3;  // 上界宽松：远多于挖穿所需
    GeneratedLevel chosen;
    chosen.difficulty = "?";
    double best_dist = 1e9;
    double center = (band.pl + (band.ph < 1.0 ? band.ph : 1.0)) / 2.0;
    for (int iter = 0; iter < 12 && lo <= hi; ++iter) {
        int mid = (lo + hi) / 2;
        Level lv = make_scroll_level(cfg, mid, seed);
        LevelEval e = evaluate_level(lv, cfg.trials);
        double p = e.skilled_pass_rate;
        double d = std::abs(p - center);
        if (d < best_dist) {  // 记录最贴近带中心的步数配置
            best_dist = d;
            chosen.level = lv;
            chosen.floor_score = e.floor_score;
            chosen.ceil_score = e.ceil_score;
            chosen.lfhc_gap = e.lfhc_gap;
            chosen.skilled_pass = p;
            chosen.difficulty = band.name;
        }
        if (p < band.pl) lo = mid + 1;        // 太难(挖不穿) → 加步数
        else if (p >= band.ph) hi = mid - 1;  // 太易 → 减步数
        else break;                           // 命中带
    }
    return chosen;
}

// 按请求难度直接产关：每个候选盘二分搜索目标值，命中该难度带才留。
// 可选扩展（默认值=原行为，不影响既有调用）：
//   wall_density>0：每个候选盘按该密度铺异形墙(WALL=-2)，做异形棋盘关。
//   force_obj>=0  ：强制目标类型（0=SCORE/1=COLLECT/2=JELLY/3=BLOCKER），跳过随机抽型，
//                   保证某类目标（尤其 BLOCKER 冰锁关）一定产出。
//   want_multi    ：COLLECT 命中后再追加一个目标（另一可收集色，或退化为清果冻），产多目标关。
inline std::vector<GeneratedLevel> generate_for_difficulty(const GenConfig& cfg, DiffBand band,
                                                           int count, int max_attempts,
                                                           double wall_density = 0.0,
                                                           int force_obj = -1,
                                                           bool want_multi = false) {
    std::vector<GeneratedLevel> out;
    std::mt19937 boardgen(cfg.base_seed);
    std::mt19937 fracgen(cfg.base_seed ^ 0x00abcdefu);
    std::uniform_real_distribution<double> fracdist(0.0, 1.0);
    const int BIG = 1 << 30;
    int attempts = 0;
    while ((int)out.size() < count && attempts < max_attempts) {
        ++attempts;
        uint32_t cand_seed = cfg.base_seed + (uint32_t)attempts * 7919u;
        // 异形墙：按候选 seed 派生墙图，传给 make_board（其余格正常填棋子且保证有合法步）。
        std::vector<std::vector<char>> wmask;
        if (wall_density > 0.0)
            wmask = _mask_from(cand_seed ^ 0x9e3779b9u, wall_density, cfg.w, cfg.h);
        Grid board = make_board(cfg.w, cfg.h, cfg.species, boardgen, wmask);
        int H = (int)board.size(), W = (int)board[0].size();
        std::vector<std::vector<int>> full_jelly(H, std::vector<int>(W, 1));
        for (int y = 0; y < H; ++y)
            for (int x = 0; x < W; ++x)
                if (board[y][x] == WALL) full_jelly[y][x] = 0;

        // raw 评估（地板/天花板 + 各色收集 + 果冻清层）
        double fsum = 0, csum = 0, gj = 0, rjsum = 0;
        std::vector<double> g_col, r_col;
        for (int t = 0; t < cfg.trials; ++t) {
            Level lv;
            lv.init_board = board;
            lv.species = cfg.species;
            lv.move_limit = cfg.move_limit;
            lv.target_score = BIG;
            lv.seed = cand_seed + (uint32_t)t * 1000003u;
            lv.jelly = full_jelly;
            PlayResult rp = random_play(lv), gp = greedy_play(lv);
            fsum += rp.score;
            csum += gp.score;
            gj += gp.jelly_cleared;
            rjsum += rp.jelly_cleared;
            if (r_col.size() < rp.collected.size()) r_col.resize(rp.collected.size(), 0.0);
            for (size_t i = 0; i < rp.collected.size(); ++i) r_col[i] += rp.collected[i];
            if (g_col.size() < gp.collected.size()) g_col.resize(gp.collected.size(), 0.0);
            for (size_t i = 0; i < gp.collected.size(); ++i) g_col[i] += gp.collected[i];
        }
        double floor_s = fsum / cfg.trials, ceil_s = csum / cfg.trials;
        double g_jelly = gj / cfg.trials;
        double r_jelly = rjsum / cfg.trials;
        if (floor_s < 1.0) continue;
        double gap = (ceil_s - floor_s) / floor_s;
        if (gap < cfg.min_gap) continue;
        for (double& v : g_col) v /= cfg.trials;
        for (double& v : r_col) v /= cfg.trials;

        // 决定目标类型 + 布局（不设 target；target 由二分搜索），并定搜索区间 [lo,hi]
        Level final;
        final.init_board = board;
        final.species = cfg.species;
        final.move_limit = cfg.move_limit;
        final.seed = cand_seed;
        int lo = 1, hi = 1;
        double u = fracdist(fracgen);
        // 强制目标类型：把 u 钳到对应分支区间，跳过随机抽型（保证 BLOCKER 等稀有目标必产）。
        if (force_obj == 1) u = cfg.collect_ratio * 0.5;                                    // COLLECT
        else if (force_obj == 2) u = cfg.collect_ratio + cfg.jelly_ratio * 0.5;             // JELLY
        else if (force_obj == 3) u = cfg.collect_ratio + cfg.jelly_ratio + cfg.blocker_ratio * 0.5;  // BLOCKER
        else if (force_obj == 0) u = 1.0;                                                   // SCORE
        bool decided = false;
        if (u < cfg.collect_ratio) {
            int best_s = -1;
            double best_gap = 0.0;
            for (size_t s = 0; s < g_col.size(); ++s) {
                if (g_col[s] < cfg.min_collect) continue;
                double rp = (s < r_col.size()) ? r_col[s] : 0.0;
                double d = g_col[s] - rp;
                if (d > best_gap) { best_gap = d; best_s = (int)s; }
            }
            if (best_s >= 0) {
                // 二分上界用目标导向天花板（smart_greedy 真追该目标），而非刷分顺带量 g_col*2
                double gd = 0.0;
                for (int t = 0; t < cfg.trials; ++t) {
                    Level probe;
                    probe.init_board = board;
                    probe.species = cfg.species;
                    probe.move_limit = cfg.move_limit;
                    probe.seed = cand_seed + (uint32_t)t * 1000003u;
                    probe.objectives = {{OBJ_COLLECT, best_s, BIG}};
                    PlayResult sp = smart_greedy_play(probe);
                    gd += (best_s < (int)sp.collected.size()) ? sp.collected[best_s] : 0;
                }
                gd /= cfg.trials;
                final.objectives = {{OBJ_COLLECT, best_s, 1}};
                lo = 1;
                hi = (int)gd + 2;
                decided = true;
            }
        }
        if (!decided && u < cfg.collect_ratio + cfg.jelly_ratio && g_jelly >= cfg.min_jelly) {
            final.jelly = full_jelly;
            final.objectives = {{OBJ_CLEAR_JELLY, -1, 1}};
            int total = 0;
            for (auto& r : full_jelly) for (int v : r) total += v;
            lo = 1;
            hi = total;
            decided = true;
        }
        if (!decided && u < cfg.collect_ratio + cfg.jelly_ratio + cfg.blocker_ratio) {
            // 强制 BLOCKER 时逐步加密，直到涂层格达标（保证冰锁关一定铺得出）。
            std::vector<std::vector<int>> coat;
            int total = 0;
            for (double dens = cfg.coat_density; dens <= 0.5; dens += 0.06) {
                std::mt19937 lr(cand_seed ^ 0x5bd1e995u);
                std::uniform_real_distribution<double> dd(0.0, 1.0);
                coat.assign(H, std::vector<int>(W, 0));
                total = 0;
                for (int y = 0; y < H; ++y)
                    for (int x = 0; x < W; ++x)
                        if (board[y][x] != WALL && dd(lr) < dens) { coat[y][x] = 1; total++; }
                if (total >= cfg.min_blocker && has_legal_move(board, &coat)) break;
                if (force_obj != 3) break;  // 非强制：维持单次尝试的原行为
            }
            if (total >= cfg.min_blocker && has_legal_move(board, &coat)) {
                final.coat = coat;
                final.objectives = {{OBJ_CLEAR_BLOCKER, -1, 1}};
                lo = 1;
                hi = total;
                decided = true;
            }
        }
        if (!decided) {  // SCORE
            final.target_score = 0;
            lo = (int)floor_s;
            hi = (int)(ceil_s * 2) + 1;
        }

        // 二分搜索 target 命中难度带（pass 随 target 单调递减）
        int found = -1;
        LevelEval fe;
        int a = lo, b = hi;
        for (int it = 0; it < 9 && a <= b; ++it) {
            int mid = a + (b - a) / 2;
            set_level_target(final, mid);
            LevelEval e = evaluate_level(final, cfg.trials);
            if (e.skilled_pass_rate > band.ph) {
                a = mid + 1;  // 太易 → 提高 target
            } else if (e.skilled_pass_rate < band.pl) {
                b = mid - 1;  // 太难 → 降低 target
            } else {
                found = mid;
                fe = e;
                break;
            }
        }
        if (found < 0) continue;  // 此盘命中不了该难度带
        set_level_target(final, found);

        // 多目标：在已标定的 COLLECT 关上追加第二目标（双色 COLLECT，或退化为清果冻），
        // 第二目标取保守小值（地板附近）以保可解；追加后复测一次，仍可解才留。
        if (want_multi && final.objectives.size() == 1 && final.objectives[0].type == OBJ_COLLECT) {
            int first_s = final.objectives[0].species;
            int second_s = -1;
            double best2 = 0.0;
            for (size_t s = 0; s < g_col.size(); ++s) {
                if ((int)s == first_s || g_col[s] < cfg.min_collect) continue;
                if (g_col[s] > best2) { best2 = g_col[s]; second_s = (int)s; }
            }
            if (second_s >= 0) {  // 双色 COLLECT：第二色目标取其随机地板量(保守)
                double rp = (second_s < (int)r_col.size()) ? r_col[second_s] : 0.0;
                int t2 = (int)rp; if (t2 < 1) t2 = 1;
                final.objectives.push_back({OBJ_COLLECT, second_s, t2});
            } else if (g_jelly >= cfg.min_jelly) {  // 退化：COLLECT + 清部分果冻
                if (final.jelly.empty()) final.jelly = full_jelly;
                int t2 = (int)(r_jelly < 1 ? 1 : r_jelly);
                final.objectives.push_back({OBJ_CLEAR_JELLY, -1, t2});
            }
            // 追加目标后复测可解性：赢不了就丢这关，保证产出关都合法。
            if (final.objectives.size() > 1) {
                LevelEval me = evaluate_level(final, cfg.trials);
                if (me.skilled_pass_rate <= 0.0) continue;
                fe = me;
            }
        }

        double rhythm = rhythm_quality(objective_progress_curve(final));

        GeneratedLevel gl;
        gl.level = final;
        gl.floor_score = floor_s;
        gl.ceil_score = ceil_s;
        gl.lfhc_gap = gap;
        gl.skilled_pass = fe.skilled_pass_rate;
        gl.rhythm = rhythm;
        gl.difficulty = band.name;
        out.push_back(gl);
    }
    return out;
}

// ---- 巧克力关生成（CLEAR_CHOCO）：仿冰锁布点 + 二分目标命中难度带 ----

// 巧克力布点：选普通棋子格(非 WALL/EMPTY)按 density 随机铺 choco=1。返回布的格数。
inline int place_chocolate(std::vector<std::vector<int>>& choco, const Grid& board,
                           double density, uint32_t seed) {
    int H = (int)board.size(), W = (int)board[0].size();
    choco.assign(H, std::vector<int>(W, 0));
    std::mt19937 rng(seed);
    std::uniform_real_distribution<double> dd(0.0, 1.0);
    int total = 0;
    for (int y = 0; y < H; ++y)
        for (int x = 0; x < W; ++x)
            if (board[y][x] != WALL && board[y][x] != EMPTY && dd(rng) < density) {
                choco[y][x] = 1;
                total++;
            }
    return total;
}

// 按请求难度产巧克力关：每候选盘强制布巧克力 + CLEAR_CHOCO 目标，二分 target 命中难度带。
// 标定核心：evaluate_level 内的玩家(random/heuristic)在 choco 关自动执行"整步零啃食→蔓延"钩子，
//   故 skilled_pass 真实反映"高手能否在蔓延压力下啃够目标数"。target 取命中带的保守地板。
inline std::vector<GeneratedLevel> generate_choco_for_difficulty(const GenConfig& cfg, DiffBand band,
                                                                 int count, int max_attempts) {
    std::vector<GeneratedLevel> out;
    std::mt19937 boardgen(cfg.base_seed ^ 0x0c0c0a11u);  // 与其它批不同盘流
    const int BIG = 1 << 30;
    int attempts = 0;
    while ((int)out.size() < count && attempts < max_attempts) {
        ++attempts;
        Grid board = make_board(cfg.w, cfg.h, cfg.species, boardgen);
        uint32_t cand_seed = cfg.base_seed + (uint32_t)attempts * 7919u;
        Level final;
        final.init_board = board;
        final.species = cfg.species;
        final.move_limit = cfg.move_limit;
        final.seed = cand_seed;

        // 布巧克力：普通棋子格按 density 铺；格数不足或布完无合法步 → 弃此盘
        std::vector<std::vector<int>> choco;
        int total = place_chocolate(choco, board, cfg.choco_density, cand_seed ^ 0xc40c0de5u);
        if (total < cfg.min_choco) continue;
        if (!gen_choco::has_legal_move(board, nullptr, &choco)) continue;
        final.choco = choco;
        final.objectives = {{OBJ_CLEAR_CHOCO, -1, 1}};

        // 二分上界：smart_greedy 全力追 CLEAR_CHOCO 实测能啃多少（目标导向天花板）
        double gd = 0.0;
        for (int t = 0; t < cfg.trials; ++t) {
            Level probe = final;
            probe.seed = cand_seed + (uint32_t)t * 1000003u;
            probe.objectives = {{OBJ_CLEAR_CHOCO, -1, BIG}};  // 大目标 → 走满步、最大化啃食
            PlayResult sp = smart_greedy_play(probe);
            gd += sp.choco_cleared;
        }
        gd /= cfg.trials;
        int lo = 1, hi = (int)gd + 2;
        if (hi < lo) continue;

        // 二分 target 命中难度带（pass 随 target 单调递减）
        int found = -1;
        LevelEval fe;
        int a = lo, b = hi;
        for (int it = 0; it < 9 && a <= b; ++it) {
            int mid = a + (b - a) / 2;
            set_level_target(final, mid);
            LevelEval e = evaluate_level(final, cfg.trials);
            if (e.skilled_pass_rate > band.ph) a = mid + 1;       // 太易 → 提高 target
            else if (e.skilled_pass_rate < band.pl) b = mid - 1;   // 太难 → 降低 target
            else { found = mid; fe = e; break; }
        }
        if (found < 0) continue;
        set_level_target(final, found);
        double rhythm = rhythm_quality(objective_progress_curve(final));

        GeneratedLevel gl;
        gl.level = final;
        gl.floor_score = fe.floor_score;
        gl.ceil_score = fe.ceil_score;
        gl.lfhc_gap = fe.lfhc_gap;
        gl.skilled_pass = fe.skilled_pass_rate;
        gl.rhythm = rhythm;
        gl.difficulty = band.name;
        out.push_back(gl);
    }
    return out;
}

// ---- FI2Pop：可行-不可行双种群遗传生成（09 §2.3）----

// 基因型：可进化的关卡设计旋钮（不含具体棋子，棋子由 board_seed 生成）。
struct Genotype {
    uint32_t board_seed = 1;
    uint32_t wall_seed = 1;
    double wall_density = 0.0;   // 0..0.15
    int obj_type = 0;            // 0 SCORE / 1 COLLECT / 2 JELLY / 3 BLOCKER
    int obj_species = 0;         // COLLECT 用
    int obj_target = 100;        // 难度旋钮
    uint32_t coat_seed = 1;
    double coat_density = 0.15;  // BLOCKER 用
    int move_limit = 16;
    double fitness = -1e9;
    bool feasible = false;
};

inline Level decode_genotype(const Genotype& g, const GenConfig& cfg) {
    int W = cfg.w, H = cfg.h;
    auto wm = _mask_from(g.wall_seed, g.wall_density, W, H);
    std::mt19937 br(g.board_seed);
    Grid board = make_board(W, H, cfg.species, br, wm);
    Level lv;
    lv.init_board = board;
    lv.species = cfg.species;
    lv.move_limit = g.move_limit;
    lv.seed = g.board_seed;
    if (g.obj_type == 1) {
        lv.objectives = {{OBJ_COLLECT, g.obj_species % (int)cfg.species.size(), g.obj_target}};
    } else if (g.obj_type == 2) {
        std::vector<std::vector<int>> j(H, std::vector<int>(W, 1));
        for (int y = 0; y < H; ++y)
            for (int x = 0; x < W; ++x)
                if (board[y][x] == WALL) j[y][x] = 0;
        lv.jelly = j;
        lv.objectives = {{OBJ_CLEAR_JELLY, -1, g.obj_target}};
    } else if (g.obj_type == 3) {
        std::mt19937 cr(g.coat_seed);
        std::uniform_real_distribution<double> dd(0.0, 1.0);
        std::vector<std::vector<int>> c(H, std::vector<int>(W, 0));
        for (int y = 0; y < H; ++y)
            for (int x = 0; x < W; ++x)
                if (board[y][x] != WALL && dd(cr) < g.coat_density) c[y][x] = 1;
        lv.coat = c;
        lv.objectives = {{OBJ_CLEAR_BLOCKER, -1, g.obj_target}};
    } else {
        lv.target_score = g.obj_target;
    }
    return lv;
}

// 一次算出违反度 + 适应度，写回 g。可行(违反=0)→软适应度；不可行→ -违反度。
inline void score_genotype(Genotype& g, const GenConfig& cfg, DiffBand band, int trials) {
    Level lv = decode_genotype(g, cfg);
    double v = 0.0;
    Grid b = lv.init_board;
    const std::vector<std::vector<int>>* coat = lv.coat.empty() ? nullptr : &lv.coat;
    if (!has_legal_move(b, coat)) v += 1.0;  // 硬约束：得有合法移动
    LevelEval e = evaluate_level(lv, trials);
    if (e.skilled_pass_rate <= 0.0) v += 1.0;  // 硬约束：目标可解
    if (v > 0.0) {
        g.feasible = false;
        g.fitness = -v;
        return;
    }
    g.feasible = true;
    double target_pass = (band.pl + (band.ph < 1.0 ? band.ph : 1.0)) / 2.0;
    double closeness = 1.0 - std::abs(e.skilled_pass_rate - target_pass);  // 难度贴近
    double depth = (e.lfhc_gap < 3.0 ? e.lfhc_gap : 3.0) / 3.0;            // 深度
    double rhythm = rhythm_quality(objective_progress_curve(lv));          // 节奏
    g.fitness = 2.0 * closeness + 0.5 * depth + 0.3 * rhythm;
}

inline Genotype random_genotype(const GenConfig& cfg, std::mt19937& rng) {
    std::uniform_real_distribution<double> u(0.0, 1.0);
    Genotype g;
    g.board_seed = rng();
    g.wall_seed = rng();
    g.wall_density = u(rng) * 0.15;
    g.obj_type = (int)(rng() % 4);
    g.obj_species = (int)(rng() % cfg.species.size());
    g.obj_target = 1 + (int)(rng() % 60);
    g.coat_seed = rng();
    g.coat_density = 0.1 + u(rng) * 0.15;
    g.move_limit = cfg.move_limit;
    return g;
}

inline Genotype mutate_genotype(const Genotype& src, const GenConfig& cfg, std::mt19937& rng) {
    Genotype g = src;
    std::uniform_real_distribution<double> u(0.0, 1.0);
    switch (rng() % 6) {
        case 0: g.board_seed = rng(); break;
        case 1: g.wall_seed = rng(); g.wall_density = std::clamp(g.wall_density + (u(rng) - 0.5) * 0.1, 0.0, 0.15); break;
        case 2: g.obj_type = (int)(rng() % 4); g.obj_species = (int)(rng() % cfg.species.size()); break;
        case 3: g.obj_target = std::clamp(g.obj_target + (int)(rng() % 21) - 10, 1, 100000); break;
        case 4: g.coat_seed = rng(); g.coat_density = std::clamp(g.coat_density + (u(rng) - 0.5) * 0.1, 0.05, 0.3); break;
        default: g.move_limit = std::clamp(g.move_limit + (int)(rng() % 7) - 3, 8, 40); break;
    }
    return g;
}

inline Genotype crossover_genotype(const Genotype& a, const Genotype& b, std::mt19937& rng) {
    Genotype c;
    c.board_seed = (rng() & 1) ? a.board_seed : b.board_seed;
    c.wall_seed = (rng() & 1) ? a.wall_seed : b.wall_seed;
    c.wall_density = (rng() & 1) ? a.wall_density : b.wall_density;
    c.obj_type = (rng() & 1) ? a.obj_type : b.obj_type;
    c.obj_species = (rng() & 1) ? a.obj_species : b.obj_species;
    c.obj_target = (rng() & 1) ? a.obj_target : b.obj_target;
    c.coat_seed = (rng() & 1) ? a.coat_seed : b.coat_seed;
    c.coat_density = (rng() & 1) ? a.coat_density : b.coat_density;
    c.move_limit = (rng() & 1) ? a.move_limit : b.move_limit;
    return c;
}

// 一个种群进化一代：精英保留 + 锦标赛选择 + 交叉 + 变异（按各自 fitness）。
inline std::vector<Genotype> _evolve_pop(std::vector<Genotype>& pop, const GenConfig& cfg,
                                         std::mt19937& rng, int target_size) {
    std::vector<Genotype> next;
    if (pop.empty() || target_size <= 0) return next;
    std::sort(pop.begin(), pop.end(), [](const Genotype& a, const Genotype& b) { return a.fitness > b.fitness; });
    int elite = std::max(1, target_size / 4);
    for (int i = 0; i < elite && i < (int)pop.size(); ++i) next.push_back(pop[i]);
    auto tournament = [&]() -> const Genotype& {
        const Genotype& x = pop[rng() % pop.size()];
        const Genotype& y = pop[rng() % pop.size()];
        return x.fitness >= y.fitness ? x : y;
    };
    while ((int)next.size() < target_size) {
        Genotype child = crossover_genotype(tournament(), tournament(), rng);
        child = mutate_genotype(child, cfg, rng);
        next.push_back(child);
    }
    return next;
}

// FI2Pop 主循环：可行/不可行双种群各自进化，后代下一代自动重分类(迁移)。返回最优可行关。
inline std::vector<GeneratedLevel> generate_fi2pop(const GenConfig& cfg, DiffBand band, int count,
                                                   int pop_size, int generations) {
    std::mt19937 rng(cfg.base_seed ^ 0x00f12b0bu);
    std::vector<Genotype> pop;
    for (int i = 0; i < pop_size; ++i) pop.push_back(random_genotype(cfg, rng));
    for (auto& g : pop) score_genotype(g, cfg, band, cfg.trials);

    for (int gen = 0; gen < generations; ++gen) {
        std::vector<Genotype> feasible, infeasible;
        for (auto& g : pop) (g.feasible ? feasible : infeasible).push_back(g);
        auto fe = _evolve_pop(feasible, cfg, rng, pop_size / 2);
        auto inf = _evolve_pop(infeasible, cfg, rng, pop_size - (int)fe.size());
        pop.clear();
        for (auto& g : fe) pop.push_back(g);
        for (auto& g : inf) pop.push_back(g);
        while ((int)pop.size() < pop_size) pop.push_back(random_genotype(cfg, rng));
        for (auto& g : pop) score_genotype(g, cfg, band, cfg.trials);  // 后代重新分类(迁移)
    }

    std::vector<Genotype> feasible;
    for (auto& g : pop) if (g.feasible) feasible.push_back(g);
    std::sort(feasible.begin(), feasible.end(), [](const Genotype& a, const Genotype& b) { return a.fitness > b.fitness; });
    std::vector<GeneratedLevel> out;
    for (int i = 0; i < (int)feasible.size() && (int)out.size() < count; ++i) {
        Level lv = decode_genotype(feasible[i], cfg);
        LevelEval e = evaluate_level(lv, cfg.trials);
        GeneratedLevel gl;
        gl.level = lv;
        gl.floor_score = e.floor_score;
        gl.ceil_score = e.ceil_score;
        gl.lfhc_gap = e.lfhc_gap;
        gl.skilled_pass = e.skilled_pass_rate;
        gl.rhythm = rhythm_quality(objective_progress_curve(lv));
        gl.difficulty = e.difficulty;
        out.push_back(gl);
    }
    return out;
}

}  // namespace me
