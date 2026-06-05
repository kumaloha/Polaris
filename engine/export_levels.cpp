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

int main(int argc, char** argv) {
    int per_band = (argc > 1) ? std::atoi(argv[1]) : 3;
    const char* out_path = (argc > 2) ? argv[2] : "godot/levels.json";

    GenConfig cfg;
    cfg.w = 9;       // 默认 9×9，对齐 Candy Crush
    cfg.h = 9;
    cfg.species = {0, 1, 2, 3, 4, 5};   // 6 色，对齐 Candy Crush
    cfg.move_limit = 25;
    cfg.trials = 12;

    // 多难度库：每档若干关，由易到难。三档【并行】生成——各档独立、各自 seed，
    // 结果与串行完全一致（确定性），只是更快（09 §6 候选并行）。
    DiffBand bands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<std::vector<GeneratedLevel>>> futs;
    for (int bi = 0; bi < 3; ++bi) {
        GenConfig c = cfg;
        c.h = 9 + bi;                                       // 各档盘高 9/10/11，增维度多样性(宽固定 9)
        c.base_seed = 12345u + (uint32_t)bi * 2654435761u;  // 各档用不同盘
        DiffBand band = bands[bi];
        futs.push_back(std::async(std::launch::async, [c, band, per_band]() {
            return generate_for_difficulty(c, band, per_band, 800);
        }));
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
    std::vector<std::future<std::vector<GeneratedLevel>>> spfuts;
    for (const SpecKind& sk : kinds) {
        for (int bi = 0; bi < 3; ++bi) {
            GenConfig c = cfg;
            c.h = 9 + bi;
            c.base_seed = sk.salt + (uint32_t)bi * 2654435761u;
            DiffBand band = bands[bi];
            int cnt = special_each;
            spfuts.push_back(std::async(std::launch::async, [c, band, cnt, sk]() {
                return generate_for_difficulty(c, band, cnt, 1200, sk.wall, sk.force, sk.multi);
            }));
        }
    }
    for (auto& f : spfuts)
        for (auto& gl : f.get())
            levels.push_back(gl);

    // 滚动/挖矿关：每档 per_band 关（与目标关同量），难度旋钮=步数(feed 深度固定/关)。
    // 变 seed + 矿深(3~5页)增多样性。三档 × per_band 全部【并行】二分校准。
    ScrollConfig sc_base;
    sc_base.w = 9;
    sc_base.h = 9;
    sc_base.species = {0, 1, 2, 3, 4, 5};   // 6 色，对齐 Candy Crush
    sc_base.trials = 8;
    const int scroll_depths[] = {3, 4, 5};   // 不同矿深(页)：首页可见，往下 2~4 页
    DiffBand sbands[] = {band_easy(), band_medium(), band_hard()};
    std::vector<std::future<GeneratedLevel>> sfuts;
    for (int bi = 0; bi < 3; ++bi) {
        for (int k = 0; k < per_band; ++k) {
            ScrollConfig sc = sc_base;
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
        GenConfig c = cfg;
        c.h = 9 + bi;                                       // 各档盘高 9/10/11
        c.base_seed = 770000u + (uint32_t)bi * 2654435761u; // 各档不同盘流
        c.choco_density = 0.10;                             // 普通棋子格 ~10% 初始巧克力
        c.min_choco = 3;
        DiffBand band = cbands[bi];
        cfuts.push_back(std::async(std::launch::async, [c, band, per_band]() {
            return generate_choco_for_difficulty(c, band, per_band, 800);
        }));
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
            c.h = 9 + bi;                  // 各档盘高 9/10/11
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
        } else if (!lv.ing.empty()) {
            int ic = 0;
            for (const auto& row : lv.ing) for (int v : row) ic += (v > 0);
            int tgt = lv.objectives.empty() ? 0 : lv.objectives[0].target;
            std::fprintf(stderr, "  lvl_%zu: [ING] diff=%s pass=%.2f target=%d initial_ing=%d exits=%zu moves=%d\n",
                         i, levels[i].difficulty, levels[i].skilled_pass, tgt, ic, lv.exit_cols.size(), lv.move_limit);
        } else {
            std::fprintf(stderr, "  lvl_%zu: diff=%s pass=%.2f gap=%.2f objs=%zu\n",
                         i, levels[i].difficulty, levels[i].skilled_pass,
                         levels[i].lfhc_gap, lv.objectives.size());
        }
    }
    return 0;
}
