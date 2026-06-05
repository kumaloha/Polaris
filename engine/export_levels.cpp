// export_levels.cpp — 关卡库导出 CLI（05 数据契约）。
// 离线跑生成器，把算法生成的关导成 JSON，供 Godot 读库摆盘。
// 编译运行（仓库根）：
//   clang++ -std=c++20 -O2 engine/export_levels.cpp -o /tmp/omc_export && /tmp/omc_export 2 godot/levels.json
#include "include/generator.hpp"
#include <cstdio>
#include <cstdlib>
#include <future>
#include <sstream>
#include <string>
using namespace me;

static std::string grid_json(const std::vector<std::vector<int>>& g) {
    if (g.empty()) return "[]";
    std::string s = "[";
    for (size_t y = 0; y < g.size(); ++y) {
        if (y) s += ",";
        s += "[";
        for (size_t x = 0; x < g[y].size(); ++x) {
            if (x) s += ",";
            s += std::to_string(g[y][x]);
        }
        s += "]";
    }
    s += "]";
    return s;
}

// 一维 int 数组序列化成 JSON（运料关出口列号用）。
static std::string int_vec_json(const std::vector<int>& v) {
    std::string s = "[";
    for (size_t i = 0; i < v.size(); ++i) {
        if (i) s += ",";
        s += std::to_string(v[i]);
    }
    s += "]";
    return s;
}

// 滚动关 feed：每列一队列(front=最先浮上来的)。序列化成 JSON 数组的数组。
static std::string feed_json(const std::vector<std::deque<int>>& feed) {
    std::string s = "[";
    for (size_t x = 0; x < feed.size(); ++x) {
        if (x) s += ",";
        s += "[";
        bool first = true;
        for (int v : feed[x]) {
            if (!first) s += ",";
            first = false;
            s += std::to_string(v);
        }
        s += "]";
    }
    s += "]";
    return s;
}

static const char* obj_type_str(ObjType t) {
    switch (t) {
        case OBJ_COLLECT: return "COLLECT";
        case OBJ_CLEAR_JELLY: return "CLEAR_JELLY";
        case OBJ_CLEAR_BLOCKER: return "CLEAR_BLOCKER";
        case OBJ_CLEAR_CHOCO: return "CLEAR_CHOCO";
        case OBJ_COLLECT_INGREDIENT: return "COLLECT_INGREDIENT";
        case OBJ_DEFUSE_BOMB: return "DEFUSE_BOMB";
        case OBJ_POP_POPCORN: return "POP_POPCORN";
        case OBJ_DESTROY_CAKE: return "DESTROY_CAKE";
        case OBJ_REVEAL_MYSTERY: return "REVEAL_MYSTERY";
        default: return "SCORE";
    }
}

static std::string level_json(const GeneratedLevel& gl, int idx) {
    const Level& lv = gl.level;
    int h = (int)lv.init_board.size();
    int w = h ? (int)lv.init_board[0].size() : 0;
    std::ostringstream o;
    o << "{";
    o << "\"level_id\":\"lvl_" << idx << "\",";
    o << "\"w\":" << w << ",\"h\":" << h << ",";
    o << "\"species\":[";
    for (size_t i = 0; i < lv.species.size(); ++i) { if (i) o << ","; o << lv.species[i]; }
    o << "],";
    o << "\"init_board\":" << grid_json(lv.init_board) << ",";
    o << "\"target_score\":" << lv.target_score << ",";
    o << "\"move_limit\":" << lv.move_limit << ",";
    o << "\"seed\":" << lv.seed << ",";
    o << "\"objectives\":[";
    for (size_t i = 0; i < lv.objectives.size(); ++i) {
        if (i) o << ",";
        const Objective& ob = lv.objectives[i];
        o << "{\"type\":\"" << obj_type_str(ob.type) << "\",\"species\":" << ob.species
          << ",\"target\":" << ob.target << "}";
    }
    o << "],";
    o << "\"jelly\":" << grid_json(lv.jelly) << ",";
    o << "\"coat\":" << grid_json(lv.coat) << ",";
    o << "\"choco\":" << grid_json(lv.choco) << ",";
    o << "\"ing\":" << grid_json(lv.ing) << ",";          // 运料关原料层(非运料关=空[])
    o << "\"exits\":" << int_vec_json(lv.exit_cols) << ",";  // 运料关出口列号数组(非运料关=空[])
    o << "\"bomb\":" << grid_json(lv.bomb) << ",";        // 炸弹关倒计时层(非炸弹关=空[]；bomb[y][x]=剩余步数)
    o << "\"cannon\":" << grid_json(lv.cannon) << ",";    // 糖果炮层(非糖果炮关=空[]；cannon[y][x]=1产糖/2产原料)
    o << "\"popcorn\":" << grid_json(lv.popcorn) << ",";  // 爆米花层(非爆米花关=空[]；popcorn[y][x]=剩余命中数)
    o << "\"cake\":" << grid_json(lv.cake) << ",";        // 蛋糕层(非蛋糕关=空[]；cake[y][x]=剩余血量)
    o << "\"mystery\":" << grid_json(lv.mystery) << ",";  // 神秘糖层(非神秘糖关=空[]；mystery[y][x]=1神秘糖)
    o << "\"difficulty\":\"" << gl.difficulty << "\",";
    o << "\"lfhc_gap\":" << gl.lfhc_gap << ",";
    o << "\"skilled_pass\":" << gl.skilled_pass;
    if (lv.is_scrolling) {  // 滚动关专属字段（普通关不带→老 Godot 读法不受影响）
        o << ",\"is_scrolling\":true";
        o << ",\"feed\":" << feed_json(lv.feed);
    }
    o << "}";
    return o.str();
}

// ═══════════════ 棋盘维度方案：宽高都多样（不再固定 9×N）═══════════════
// 用户要求：不固定 8×8，可能 9×9、甚至 9×11，每关可不同。故定义维度池覆盖 8×8 ~ 9×11，
// 宽∈{8,9}、高∈{8..11} 都有分布。各关批按"难度档 bi + 关内 index k"组合轮选池中维度，
// 使同一关型不同关落在不同盘形上（确定性：同 bi/k 永远同维度，库可复现）。
struct Dim { int w, h; };
// 维度池：含用户的例子(8×8 / 9×9 / 9×11)及中间值(8×9 / 9×10 / 8×10)。顺序经排布让轮选时
// 宽/高交替变化，避免连续多关同形。
static const Dim DIM_POOL[] = {
    {8, 8}, {9, 9}, {8, 10}, {9, 11}, {8, 9}, {9, 10},
};
static const int DIM_POOL_N = (int)(sizeof(DIM_POOL) / sizeof(DIM_POOL[0]));

// 普通轮选：按"全局序号 idx"取池中维度。idx 一般取 bi*per_band + k（关批内唯一推进），
// 保证每个关型的各关铺开覆盖整个池（含 8×8 与 9×11）。
static Dim pick_dim(int idx) {
    return DIM_POOL[((idx % DIM_POOL_N) + DIM_POOL_N) % DIM_POOL_N];
}

// 偏大盘轮选（8×8 标定难的关型用）：跳过纯 8×8(更小更挤、障碍密度高易标不出/产出少)，
// 只在 {9×9, 8×10, 9×11, 8×9, 9×10} 里轮——仍含 8 宽与多种高，维度依旧多样，但不落最小盘。
// 用于异形墙(多障碍)与后 4 层(cannon/popcorn/cake/mystery 特效标定保守)，确保每档每型都有产出。
static Dim pick_dim_biglean(int idx) {
    static const Dim BIG_POOL[] = { {9, 9}, {8, 10}, {9, 11}, {8, 9}, {9, 10} };
    static const int N = (int)(sizeof(BIG_POOL) / sizeof(BIG_POOL[0]));
    return BIG_POOL[((idx % N) + N) % N];
}

int main(int argc, char** argv) {
    int per_band = (argc > 1) ? std::atoi(argv[1]) : 3;
    const char* out_path = (argc > 2) ? argv[2] : "godot/levels.json";

    GenConfig cfg;
    cfg.w = 9;       // 兜底默认（实际各关批用 pick_dim 覆盖宽高，见下）
    cfg.h = 9;
    cfg.species = {0, 1, 2, 3, 4, 5};   // 6 色，对齐 Candy Crush
    cfg.move_limit = 25;
    cfg.trials = 12;

    // 多难度库：每档若干关，由易到难。三档 × 关内 index 全部【并行】生成——各关独立、各自 seed，
    // 结果与串行完全一致（确定性），只是更快（09 §6 候选并行）。
    // 维度：每关按 pick_dim(bi*per_band+k) 轮选不同 (w,h)，故同档内各关盘形不同（覆盖 8×8 ~ 9×11）。
    DiffBand bands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<std::vector<GeneratedLevel>>> futs;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            GenConfig c = cfg;
            Dim dm = pick_dim(bi * per_band + k);
            c.w = dm.w; c.h = dm.h;                              // 宽高都多样
            c.base_seed = 12345u + (uint32_t)(bi * per_band + k) * 2654435761u;  // 各关用不同盘
            DiffBand band = bands[bi];
            futs.push_back(std::async(std::launch::async, [c, band]() {
                return generate_for_difficulty(c, band, 1, 800);  // 每次产 1 关（该关专属维度）
            }));
        }
    }
    std::vector<GeneratedLevel> levels;
    for (auto& f : futs)
        for (auto& gl : f.get())
            levels.push_back(gl);

    // 专项关：保证每难度档都有「异形墙 / 冰锁(blocker) / 多目标」三类各若干，补足库的丰富度。
    // 各类用独立 base_seed（与上面随机档错开），靠 generate_for_difficulty 的扩展旋钮强制产出。
    //   - 墙关 ：wall_density 0.10，init_board 出现 -2（异形棋盘）
    //   - 冰锁 ：force_obj=3，coat 非空（CLEAR_BLOCKER）
    //   - 多目标：force_obj=1(COLLECT)+want_multi，objectives 含 2 项（双色 COLLECT 或 +清果冻）
    int special_each = std::max(1, per_band / 2);   // 每档每类关数，随 per_band 增长
    struct SpecKind { double wall; int force; bool multi; uint32_t salt; };
    SpecKind kinds[] = {
        {0.10, -1, false, 0x10000001u},   // 异形墙（目标类型仍随机）
        {0.00,  3, false, 0x20000002u},   // 冰锁 blocker
        {0.00,  1, true,  0x30000003u},   // 多目标
    };
    // 每类每档逐关产 1 个，按 index 轮选维度。异形墙(多障碍)在小盘易标不出 → 用 pick_dim_biglean
    // 偏大盘(跳过纯 8×8、仍含 8 宽多种高)；blocker/multi 用普通 pick_dim(含 8×8)。维度依旧多样。
    std::vector<std::future<std::vector<GeneratedLevel>>> spfuts;
    for (const SpecKind& sk : kinds) {
        bool is_wall = sk.wall > 0.0;
        for (int bi = 0; bi < 3; ++bi) {
            for (int k = 0; k < special_each; ++k) {
                GenConfig c = cfg;
                Dim dm = is_wall ? pick_dim_biglean(bi * special_each + k)
                                 : pick_dim(bi * special_each + k);
                c.w = dm.w; c.h = dm.h;
                c.base_seed = sk.salt + (uint32_t)(bi * special_each + k) * 2654435761u;
                DiffBand band = bands[bi];
                spfuts.push_back(std::async(std::launch::async, [c, band, sk]() {
                    return generate_for_difficulty(c, band, 1, 1200, sk.wall, sk.force, sk.multi);
                }));
            }
        }
    }
    for (auto& f : spfuts)
        for (auto& gl : f.get())
            levels.push_back(gl);

    // 滚动/挖矿关：每档 per_band 关（与目标关同量），难度旋钮=步数(feed 深度固定/关)。
    // 变 seed + 矿深(3~5页)增多样性。三档 × per_band 全部【并行】二分校准。
    ScrollConfig sc_base;
    sc_base.w = 9;                          // 兜底默认（实际每关 pick_dim 覆盖宽高）
    sc_base.h = 9;
    sc_base.species = {0, 1, 2, 3, 4, 5};   // 6 色，对齐 Candy Crush
    sc_base.trials = 8;
    const int scroll_depths[] = {3, 4, 5};   // 不同矿深(页)：首页可见，往下 2~4 页
    DiffBand sbands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<GeneratedLevel>> sfuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            ScrollConfig sc = sc_base;
            Dim dm = pick_dim(bi * per_band + k);   // 每关不同 (w,h)
            sc.w = dm.w; sc.h = dm.h;
            sc.depth_pages = scroll_depths[k % 3];   // 关间轮换矿深
            DiffBand band = sbands[bi];
            uint32_t seed = 990000u + (uint32_t)(bi * per_band + k) * 2654435761u;
            sfuts.push_back(std::async(std::launch::async, [sc, band, seed]() {
                return generate_scroll_for_difficulty(sc, band, seed);
            }));
        }
    }
    for (auto& f : sfuts)
        levels.push_back(f.get());

    // 巧克力关：每档 per_band 关（CLEAR_CHOCO 蔓延压力源）。强制布巧克力 + 二分目标校准。
    // 与目标关同盘维度(9×9/10/11)、不同 seed 流。三档全部【并行】生成。
    DiffBand cbands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<std::vector<GeneratedLevel>>> cfuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            GenConfig c = cfg;
            Dim dm = pick_dim(bi * per_band + k);               // 每关不同 (w,h)
            c.w = dm.w; c.h = dm.h;
            c.base_seed = 770000u + (uint32_t)(bi * per_band + k) * 2654435761u; // 各关不同盘流
            c.choco_density = 0.10;                             // 普通棋子格 ~10% 初始巧克力
            c.min_choco = 3;
            DiffBand band = cbands[bi];
            cfuts.push_back(std::async(std::launch::async, [c, band]() {
                return generate_choco_for_difficulty(c, band, 1, 800);
            }));
        }
    }
    for (auto& f : cfuts)
        for (auto& gl : f.get())
            levels.push_back(gl);

    // 运料关：每档 per_band 关（COLLECT_INGREDIENT：把原料运到底部出口）。顶部撒原料 + 底行全列出口，
    // 固定充裕步数 + 二分 target 校准难度。与其它档同盘维度(9×9/10/11)、不同 seed 流。三档全部【并行】生成。
    DiffBand ibands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<GeneratedLevel>> ifuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            GenConfig c = cfg;
            Dim dm = pick_dim(bi * per_band + k);   // 每关不同 (w,h)
            c.w = dm.w; c.h = dm.h;
            c.ing_rows = 2 + bi;           // 难档撒得更高(运送距离更远)
            c.ing_density = 0.18;
            c.min_ingredient = 3;
            DiffBand band = ibands[bi];
            uint32_t seed = 550000u + (uint32_t)(bi * per_band + k) * 2654435761u;
            ifuts.push_back(std::async(std::launch::async, [c, band, seed]() {
                return generate_ingredient_for_difficulty(c, band, seed);
            }));
        }
    }
    for (auto& f : ifuts) {
        GeneratedLevel gl = f.get();
        if (!gl.level.ing.empty()) levels.push_back(gl);  // 防御：极端凑不出可用盘时跳过(几乎不发生)
    }

    // 炸弹关：每档 per_band 关（OBJ_DEFUSE_BOMB：限步内拆够 N 个倒计时炸弹且全程不爆）。撒倒计时炸弹 +
    // 二分 target 校准难度。倒计时给宽(留拆弹窗口)，紧迫度激励让画像玩家主动拆将爆的弹→可解关标得出。
    // 与其它档同盘维度(9×9/10/11)、不同 seed 流。三档全部【并行】生成。
    DiffBand bbands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<std::vector<GeneratedLevel>>> bfuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            GenConfig c = cfg;
            Dim dm = pick_dim(bi * per_band + k);               // 每关不同 (w,h)
            c.w = dm.w; c.h = dm.h;
            c.base_seed = 660000u + (uint32_t)(bi * per_band + k) * 2654435761u; // 各关不同盘流
            c.bomb_density = 0.12;                              // 普通棋子格 ~12% 撒炸弹
            c.min_bomb = 3;
            DiffBand band = bbands[bi];
            bfuts.push_back(std::async(std::launch::async, [c, band]() {
                return generate_bomb_for_difficulty(c, band, 1, 800);
            }));
        }
    }
    for (auto& f : bfuts)
        for (auto& gl : f.get())
            levels.push_back(gl);

    // ═══════════ H5：四个"死功能"障碍专项关批（cannon / popcorn / cake / mystery）═══════════
    // 每档 per_band 关（与运料/滚动同量），二分 target 校准难度。盘维度 9×9/10/11，各层独立 seed 流。
    // 特效标定难题处理：cake/mystery 普通三消即触发(标定直接)；popcorn 用保守溅射几何近似 +
    //   cannon 用起手原料保证目标可达(炮口产出为额外供给)——均偏保守，确保真机可解(呼应铁律)。

    // 糖果炮关（OBJ_COLLECT_INGREDIENT，cannon=2 产原料）：顶行布炮 + 靠底起手原料 + 底行出口。
    DiffBand cnbands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<GeneratedLevel>> cnfuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            GenConfig c = cfg;
            Dim dm = pick_dim_biglean(bi * per_band + k);  // 偏大盘(后4层特效标定保守，避最小 8×8)
            c.w = dm.w; c.h = dm.h;
            c.cannon_count = 3 + bi;       // 难档多布一门炮
            c.min_cannon = 2;
            DiffBand band = cnbands[bi];
            uint32_t seed = 440000u + (uint32_t)(bi * per_band + k) * 2654435761u;
            cnfuts.push_back(std::async(std::launch::async, [c, band, seed]() {
                return generate_cannon_for_difficulty(c, band, seed);
            }));
        }
    }
    for (auto& f : cnfuts) {
        GeneratedLevel gl = f.get();
        if (!gl.level.cannon.empty()) levels.push_back(gl);  // 防御：极端凑不出可用盘时跳过
    }

    // 爆米花关（OBJ_POP_POPCORN）：撒爆米花格 + 保守二分 target（裸 Core 溅射命中近似，标定最保守）。
    DiffBand pcbands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<GeneratedLevel>> pcfuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            GenConfig c = cfg;
            Dim dm = pick_dim_biglean(bi * per_band + k);  // 偏大盘(爆米花溅射近似最保守，避最小 8×8)
            c.w = dm.w; c.h = dm.h;
            c.mystery_density = 0.10 + 0.02 * bi;  // 复用 mystery_density 作撒布概率口径（难档略密）
            c.popcorn_hp = 1;                 // 保守：命中数 1（裸 Core 溅射近似易达成）
            c.min_popcorn = 3;
            DiffBand band = pcbands[bi];
            uint32_t seed = 330000u + (uint32_t)(bi * per_band + k) * 2654435761u;
            pcfuts.push_back(std::async(std::launch::async, [c, band, seed]() {
                return generate_popcorn_for_difficulty(c, band, seed);
            }));
        }
    }
    for (auto& f : pcfuts) {
        GeneratedLevel gl = f.get();
        if (!gl.level.popcorn.empty()) levels.push_back(gl);
    }

    // 蛋糕关（OBJ_DESTROY_CAKE）：撒蛋糕(grid=WALL) + 保守二分 target。
    DiffBand ckbands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<GeneratedLevel>> ckfuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            GenConfig c = cfg;
            Dim dm = pick_dim_biglean(bi * per_band + k);  // 偏大盘(蛋糕引爆链保守，避最小 8×8)
            c.w = dm.w; c.h = dm.h;
            c.cake_density = 0.06;         // 普通棋子格 ~6% 撒蛋糕
            c.cake_hp = 2;                 // 保守：血量 2
            c.min_cake = 2;
            DiffBand band = ckbands[bi];
            uint32_t seed = 220000u + (uint32_t)(bi * per_band + k) * 2654435761u;
            ckfuts.push_back(std::async(std::launch::async, [c, band, seed]() {
                return generate_cake_for_difficulty(c, band, seed);
            }));
        }
    }
    for (auto& f : ckfuts) {
        GeneratedLevel gl = f.get();
        if (!gl.level.cake.empty()) levels.push_back(gl);
    }

    // 神秘糖关（OBJ_REVEAL_MYSTERY）：铺神秘糖(普通棋子) + 二分 target（被消即揭开，标定相对直接）。
    DiffBand mybands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<GeneratedLevel>> myfuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            GenConfig c = cfg;
            Dim dm = pick_dim_biglean(bi * per_band + k);  // 偏大盘(神秘糖标定相对直接但仍避最小 8×8 保稳)
            c.w = dm.w; c.h = dm.h;
            c.mystery_density = 0.12;      // 普通棋子格 ~12% 铺神秘糖
            c.min_mystery = 3;
            DiffBand band = mybands[bi];
            uint32_t seed = 110000u + (uint32_t)(bi * per_band + k) * 2654435761u;
            myfuts.push_back(std::async(std::launch::async, [c, band, seed]() {
                return generate_mystery_for_difficulty(c, band, seed);
            }));
        }
    }
    for (auto& f : myfuts) {
        GeneratedLevel gl = f.get();
        if (!gl.level.mystery.empty()) levels.push_back(gl);
    }

    std::ostringstream o;
    o << "{\"levels\":[";
    for (size_t i = 0; i < levels.size(); ++i) {
        if (i) o << ",";
        o << level_json(levels[i], (int)i);
    }
    o << "]}";

    FILE* f = std::fopen(out_path, "w");
    if (!f) { std::fprintf(stderr, "cannot open %s\n", out_path); return 1; }
    std::fputs(o.str().c_str(), f);
    std::fclose(f);
    std::fprintf(stderr, "exported %zu levels -> %s\n", levels.size(), out_path);
    for (size_t i = 0; i < levels.size(); ++i) {
        const Level& lv = levels[i].level;
        if (lv.is_scrolling) {
            int depth = lv.feed.empty() ? 0 : (int)lv.feed[0].size();
            std::fprintf(stderr, "  lvl_%zu: [SCROLL] diff=%s pass=%.2f moves=%d feed=%d/col\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, lv.move_limit, depth);
        } else if (!lv.choco.empty()) {
            int cc = 0;
            for (const auto& row : lv.choco) for (int v : row) cc += (v > 0);
            int tgt = lv.objectives.empty() ? 0 : lv.objectives[0].target;
            std::fprintf(stderr, "  lvl_%zu: [CHOCO] diff=%s pass=%.2f target=%d initial_choco=%d\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, tgt, cc);
        } else if (!lv.cannon.empty()) {  // 糖果炮关须先于 ing 判（其 ing 层非空=起手原料）
            int cn = 0;
            for (const auto& row : lv.cannon) for (int v : row) cn += (v > 0);
            int ic = 0;
            for (const auto& row : lv.ing) for (int v : row) ic += (v > 0);
            int tgt = lv.objectives.empty() ? 0 : lv.objectives[0].target;
            std::fprintf(stderr, "  lvl_%zu: [CANNON] diff=%s pass=%.2f target=%d cannons=%d starter_ing=%d moves=%d\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, tgt, cn, ic, lv.move_limit);
        } else if (!lv.popcorn.empty()) {
            int pc = 0;
            for (const auto& row : lv.popcorn) for (int v : row) pc += (v > 0);
            int tgt = lv.objectives.empty() ? 0 : lv.objectives[0].target;
            std::fprintf(stderr, "  lvl_%zu: [POPCORN] diff=%s pass=%.2f target=%d initial_popcorn=%d moves=%d\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, tgt, pc, lv.move_limit);
        } else if (!lv.cake.empty()) {
            int kc = 0;
            for (const auto& row : lv.cake) for (int v : row) kc += (v > 0);
            int tgt = lv.objectives.empty() ? 0 : lv.objectives[0].target;
            std::fprintf(stderr, "  lvl_%zu: [CAKE] diff=%s pass=%.2f target=%d initial_cake=%d moves=%d\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, tgt, kc, lv.move_limit);
        } else if (!lv.mystery.empty()) {
            int mc = 0;
            for (const auto& row : lv.mystery) for (int v : row) mc += (v > 0);
            int tgt = lv.objectives.empty() ? 0 : lv.objectives[0].target;
            std::fprintf(stderr, "  lvl_%zu: [MYSTERY] diff=%s pass=%.2f target=%d initial_mystery=%d moves=%d\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, tgt, mc, lv.move_limit);
        } else if (!lv.ing.empty()) {
            int ic = 0;
            for (const auto& row : lv.ing) for (int v : row) ic += (v > 0);
            int tgt = lv.objectives.empty() ? 0 : lv.objectives[0].target;
            std::fprintf(stderr, "  lvl_%zu: [ING] diff=%s pass=%.2f target=%d initial_ing=%d exits=%zu moves=%d\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, tgt, ic, lv.exit_cols.size(), lv.move_limit);
        } else if (!lv.bomb.empty()) {
            int bc = 0, ttl = 0;
            for (const auto& row : lv.bomb) for (int v : row) if (v > 0) { bc++; ttl = v; }
            int tgt = lv.objectives.empty() ? 0 : lv.objectives[0].target;
            std::fprintf(stderr, "  lvl_%zu: [BOMB] diff=%s pass=%.2f target=%d bombs=%d ttl=%d moves=%d\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, tgt, bc, ttl, lv.move_limit);
        } else {
            std::fprintf(stderr, "  lvl_%zu: diff=%s pass=%.2f gap=%.2f objs=%zu\n",
                         i, levels[i].difficulty, levels[i].skilled_pass,
                         levels[i].lfhc_gap, lv.objectives.size());
        }
    }
    return 0;
}
