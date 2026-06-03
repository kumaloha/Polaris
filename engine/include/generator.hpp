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
    double frac_lo = 0.35;    // 目标分落点下界（floor..ceil 之间）
    double frac_hi = 0.85;    // 目标分落点上界
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

        // raw 评估：target 设很大 → 玩家走满步 → 测地板/天花板原始分
        double fsum = 0, csum = 0;
        for (int t = 0; t < cfg.trials; ++t) {
            Level lv;
            lv.init_board = board;
            lv.species = cfg.species;
            lv.move_limit = cfg.move_limit;
            lv.target_score = BIG;
            lv.seed = cand_seed + (uint32_t)t * 1000003u;
            fsum += random_play(lv).score;
            csum += greedy_play(lv).score;
        }
        double floor_s = fsum / cfg.trials;
        double ceil_s = csum / cfg.trials;
        if (floor_s < 1.0) continue;
        double gap = (ceil_s - floor_s) / floor_s;
        if (gap < cfg.min_gap) continue;  // 没深度 → 弃

        // 自动定目标：落在 floor..ceil 甜区 → 地板(均)够不到、天花板够得到
        double frac = fracdist(fracgen);
        int target = (int)(floor_s + frac * (ceil_s - floor_s));
        if (target <= (int)floor_s) target = (int)floor_s + 1;

        Level final;
        final.init_board = board;
        final.species = cfg.species;
        final.move_limit = cfg.move_limit;
        final.target_score = target;
        final.seed = cand_seed;
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
