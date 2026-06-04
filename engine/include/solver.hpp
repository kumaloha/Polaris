#pragma once
// solver.hpp — 求解器（09 §3）。求解器既是"玩家"也是"评估器"。
// v1：贪心玩家(地板代言人)。后续加 MCTS(天花板)、Beam、投票评估。
#include "match_engine.hpp"
#include <cstdint>

namespace me {

enum ObjType { OBJ_SCORE, OBJ_COLLECT, OBJ_CLEAR_JELLY, OBJ_CLEAR_BLOCKER };

struct Objective {
    ObjType type = OBJ_SCORE;
    int species = -1;  // COLLECT 用
    int target = 0;
};

struct Level {
    Grid init_board;
    std::vector<int> species;
    int target_score = 0;             // 旧式：objectives 为空时按它判胜（向后兼容）
    int move_limit = 0;
    uint32_t seed = 0;
    std::vector<Objective> objectives;          // 新式：多目标，全满足即过关
    std::vector<std::vector<int>> jelly;        // 果冻层（底层目标，可选）
    std::vector<std::vector<int>> coat;         // 涂层冰/锁（hp 层，可选）
};

// 把一次消除的 by_species 累加进总收集表。
inline void accumulate(std::vector<int>& acc, const std::vector<int>& add) {
    if (acc.size() < add.size()) acc.resize(add.size(), 0);
    for (size_t i = 0; i < add.size(); ++i) acc[i] += add[i];
}

// 是否过关：objectives 为空 → 旧式 score>=target_score；否则全部目标满足。
inline bool objectives_met(const Level& lv, int score, const std::vector<int>& collected,
                           int jelly_cleared = 0, int blocker_cleared = 0) {
    if (lv.objectives.empty())
        return score >= lv.target_score;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE) {
            if (score < o.target) return false;
        } else if (o.type == OBJ_COLLECT) {
            int got = (o.species >= 0 && o.species < (int)collected.size()) ? collected[o.species] : 0;
            if (got < o.target) return false;
        } else if (o.type == OBJ_CLEAR_JELLY) {
            if (jelly_cleared < o.target) return false;
        } else if (o.type == OBJ_CLEAR_BLOCKER) {
            if (blocker_cleared < o.target) return false;
        }
    }
    return true;
}

struct Move {
    Vec2 a, b;
};

struct PlayResult {
    bool won = false;
    int score = 0;
    int moves_used = 0;
    int jelly_cleared = 0;       // 累计清掉的果冻层
    int blocker_cleared = 0;     // 累计破掉的涂层(冰/锁)层
    std::vector<int> collected;  // 各 species 累计消除数
};

// 一步交换的"价值"：朝当前目标推进多少（目标感知，不是单纯分数）。
// SCORE→分数；COLLECT→消的目标色数×W；JELLY/BLOCKER→清的层数×W；分数当次要项。
// 无目标 → 退化为纯分数（与老贪心一致）。
inline double move_value(const ResolveResult& rr, const Level& lv) {
    if (lv.objectives.empty()) return (double)rr.score;
    const double W = 100.0;  // 目标进度远重于分数
    double v = 0.0;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE) {
            v += rr.score;
        } else if (o.type == OBJ_COLLECT) {
            int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
            v += W * g;
        } else if (o.type == OBJ_CLEAR_JELLY) {
            v += W * rr.jelly_cleared;
        } else if (o.type == OBJ_CLEAR_BLOCKER) {
            v += W * rr.blocker_cleared;
        }
    }
    v += 0.01 * rr.score;  // 同等目标进度下，分高者优
    return v;
}

// 枚举所有合法交换。
inline std::vector<Move> legal_moves(Grid& g, const std::vector<std::vector<int>>* coat = nullptr) {
    std::vector<Move> out;
    int h = (int)g.size();
    if (h == 0) return out;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && is_legal_swap(g, {x, y}, {x + 1, y}, coat)) out.push_back({{x, y}, {x + 1, y}});
            if (y + 1 < h && is_legal_swap(g, {x, y}, {x, y + 1}, coat)) out.push_back({{x, y}, {x, y + 1}});
        }
    return out;
}

// 贪心玩家：每步选"立即得分最高"的交换。代表不规划的休闲玩家=地板。
inline PlayResult greedy_play(const Level& lv) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    while (res.moves_used < lv.move_limit && !objectives_met(lv, res.score, collected, jelly_total, blocker_total)) {
        auto moves = legal_moves(g, coat.empty() ? nullptr : &coat);
        if (moves.empty()) break;  // 死局（v1 暂不洗牌，罕见；TODO 接 reshuffle）
        // 在副本上试每个候选，取立即得分最高（rng 也拷贝，保证选中后真实结算一致）
        int best_gain = -1;
        Move best = moves[0];
        for (const auto& m : moves) {
            Grid gc = g;
            std::mt19937 rc = rng;
            swap_cells(gc, m.a, m.b);
            int gain = resolve(gc, lv.species, rc).score;
            if (gain > best_gain) {
                best_gain = gain;
                best = m;
            }
        }
        swap_cells(g, best.a, best.b);
        ResolveResult rr = resolve(g, lv.species, rng, jelly.empty() ? nullptr : &jelly,
                                   coat.empty() ? nullptr : &coat);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total);
    return res;
}

// flat Monte-Carlo 玩家（MCTS-lite，09 §3.4 精神）：每步对每个候选做若干随机 rollout
// 取均值，选期望最优。代表"会规划/采样未来"的高水平玩家 = 天花板。
// rollout 用独立、按步派生的 rng（不污染真实推进 rng；同 it 跨候选同随机=公平）。
inline PlayResult mc_play(const Level& lv, int rollouts = 8, int rollout_depth = 4) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);  // 真实推进用
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    while (res.moves_used < lv.move_limit && !objectives_met(lv, res.score, collected, jelly_total, blocker_total)) {
        auto moves = legal_moves(g, coat.empty() ? nullptr : &coat);
        if (moves.empty()) break;
        // 本步 rollout 的基准种子（独立于真实 rng；同 it 跨候选同随机 = 公平）
        uint32_t step_seed = lv.seed + (uint32_t)(res.moves_used + 1) * 2654435761u;
        double best = -1.0;
        Move bestm = moves[0];
        for (const auto& m : moves) {
            double sum = 0.0;
            for (int it = 0; it < rollouts; ++it) {
                std::mt19937 rc(step_seed + (uint32_t)it * 40503u);
                Grid gc = g;
                swap_cells(gc, m.a, m.b);
                int s = resolve(gc, lv.species, rc).score;
                for (int d = 0; d < rollout_depth; ++d) {
                    auto ms = legal_moves(gc);
                    if (ms.empty()) break;
                    Move rm = ms[rc() % ms.size()];
                    swap_cells(gc, rm.a, rm.b);
                    s += resolve(gc, lv.species, rc).score;
                }
                sum += s;
            }
            double avg = sum / rollouts;
            if (avg > best) {
                best = avg;
                bestm = m;
            }
        }
        swap_cells(g, bestm.a, bestm.b);
        ResolveResult rr = resolve(g, lv.species, rng, jelly.empty() ? nullptr : &jelly,
                                   coat.empty() ? nullptr : &coat);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total);
    return res;
}

// 目标感知贪心：每步选"朝目标推进最多"的交换（move_value），而非最大分。
// 这是真正"会玩这关的高手" = 可信天花板。候选评估带 jelly/coat 拷贝以量出目标进度。
inline PlayResult smart_greedy_play(const Level& lv) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    while (res.moves_used < lv.move_limit
           && !objectives_met(lv, res.score, collected, jelly_total, blocker_total)) {
        auto moves = legal_moves(g, coat.empty() ? nullptr : &coat);
        if (moves.empty()) break;
        double best_v = -1e18;
        Move best = moves[0];
        for (const auto& m : moves) {
            Grid gc = g;
            std::mt19937 rc = rng;
            std::vector<std::vector<int>> jc = jelly;
            std::vector<std::vector<int>> cc = coat;
            swap_cells(gc, m.a, m.b);
            ResolveResult rr = resolve(gc, lv.species, rc,
                                       jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc);
            double v = move_value(rr, lv);
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        ResolveResult rr = resolve(g, lv.species, rng,
                                   jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total);
    return res;
}

// 随机玩家：每步随便选一个合法交换。真正的"无脑休闲玩家" = 地板下沿。
inline PlayResult random_play(const Level& lv) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    while (res.moves_used < lv.move_limit && !objectives_met(lv, res.score, collected, jelly_total, blocker_total)) {
        auto moves = legal_moves(g, coat.empty() ? nullptr : &coat);
        if (moves.empty()) break;
        Move m = moves[rng() % moves.size()];
        swap_cells(g, m.a, m.b);
        ResolveResult rr = resolve(g, lv.species, rng, jelly.empty() ? nullptr : &jelly,
                                   coat.empty() ? nullptr : &coat);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total);
    return res;
}

// 关卡评估（09 §4 投票精神简化版）：一组不同水平玩家各跑 trials 次（不同 seed）取平均，
// 由"地板(random) vs 天花板(greedy)"的差距得 LFHC，由技巧玩家通过率得难度档。
struct LevelEval {
    double floor_score = 0;       // 随机玩家平均分
    double ceil_score = 0;        // 贪心玩家平均分
    double lfhc_gap = 0;          // (ceil-floor)/floor：越大越有规划回报 = 天花板越高
    double skilled_pass_rate = 0; // 贪心通过率（难度反指标）
    const char* difficulty = "?";
};

inline LevelEval evaluate_level(const Level& base, int trials = 8) {
    double fsum = 0, csum = 0;
    int wins = 0;
    for (int t = 0; t < trials; ++t) {
        Level lv = base;
        lv.seed = base.seed + (uint32_t)t * 1000003u;  // 每次试不同随机流
        fsum += random_play(lv).score;
        PlayResult gr = smart_greedy_play(lv);  // 目标感知天花板
        csum += gr.score;
        if (gr.won) ++wins;
    }
    LevelEval e;
    e.floor_score = fsum / trials;
    e.ceil_score = csum / trials;
    e.lfhc_gap = (e.ceil_score - e.floor_score) / (e.floor_score < 1.0 ? 1.0 : e.floor_score);
    e.skilled_pass_rate = (double)wins / trials;
    double p = e.skilled_pass_rate;
    e.difficulty = p > 0.8 ? "EASY" : p > 0.4 ? "MEDIUM" : p > 0.1 ? "HARD" : "EXPERT";
    return e;
}

}  // namespace me
