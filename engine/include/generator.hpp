#pragma once
// generator.hpp — 生成-评估闭环（09 §2.7 generate-and-test + §4 投票 + §6 筛选）。
// 流程：造候选盘面 → 求解器组评估(地板/天花板) → 按 LFHC 深度筛
//       → 自动把目标分定在「地板失败、天花板通过」的甜区 → 产出带难度标签的关卡库。
#include "solver.hpp"

namespace me {

struct GenConfig {
    int w = 8, h = 8;
    std::vector<int> species = {0, 1, 2, 3, 4};
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
    uint32_t base_seed = 1;
};

struct GeneratedLevel {
    Level level;               // 含已定好的 target_score
    double floor_score = 0;    // random 玩家原始均分（地板）
    double ceil_score = 0;     // greedy 玩家原始均分（天花板）
    double lfhc_gap = 0;       // (ceil-floor)/floor
    double skilled_pass = 0;   // 定目标后技巧玩家通过率
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
                double rp = (best_s < (int)r_col.size()) ? r_col[best_s] : 0.0;
                double ct = rp + frac * (g_col[best_s] - rp);
                final.objectives = {{OBJ_COLLECT, best_s, (int)(ct < 1 ? 1 : ct)}};
                decided = true;
            }
        }
        if (!decided && u < cfg.collect_ratio + cfg.jelly_ratio && g_jelly >= cfg.min_jelly) {  // 清果冻
            int ct = (int)(r_jelly + frac * (g_jelly - r_jelly));
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

        GeneratedLevel gl;
        gl.level = final;
        gl.floor_score = floor_s;
        gl.ceil_score = ceil_s;
        gl.lfhc_gap = gap;
        gl.skilled_pass = fe.skilled_pass_rate;
        gl.difficulty = fe.difficulty;
        out.push_back(gl);
    }
    return out;
}

}  // namespace me
