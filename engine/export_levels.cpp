// export_levels.cpp — 关卡库导出 CLI（05 数据契约）。
// 离线跑生成器，把算法生成的关导成 JSON，供 Godot 读库摆盘。
// 编译运行（仓库根）：
//   clang++ -std=c++20 -O2 engine/export_levels.cpp -o /tmp/omc_export && /tmp/omc_export 2 godot/levels.json
#include "include/generator.hpp"
#include <cstdio>
#include <cstdlib>
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

static const char* obj_type_str(ObjType t) {
    switch (t) {
        case OBJ_COLLECT: return "COLLECT";
        case OBJ_CLEAR_JELLY: return "CLEAR_JELLY";
        case OBJ_CLEAR_BLOCKER: return "CLEAR_BLOCKER";
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
    o << "\"difficulty\":\"" << gl.difficulty << "\",";
    o << "\"lfhc_gap\":" << gl.lfhc_gap << ",";
    o << "\"skilled_pass\":" << gl.skilled_pass;
    o << "}";
    return o.str();
}

int main(int argc, char** argv) {
    int count = (argc > 1) ? std::atoi(argv[1]) : 2;
    const char* out_path = (argc > 2) ? argv[2] : "godot/levels.json";

    GenConfig cfg;
    cfg.w = 8;
    cfg.h = 8;
    cfg.species = {0, 1, 2, 3, 4};
    cfg.move_limit = 25;
    cfg.base_seed = 12345;
    cfg.trials = 12;

    auto levels = generate_and_test(cfg, count, 400);

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
    for (size_t i = 0; i < levels.size(); ++i)
        std::fprintf(stderr, "  lvl_%zu: diff=%s pass=%.2f gap=%.2f objs=%zu\n",
                     i, levels[i].difficulty, levels[i].skilled_pass,
                     levels[i].lfhc_gap, levels[i].level.objectives.size());
    return 0;
}
