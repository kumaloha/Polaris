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
    std::vector<int> solspace_curve;  // 每步"能产生消除的有效交换数"（局内节奏）
};

// 局内节奏评分：前松后紧 = 前半段可选步均值 > 后半段，越大越好（09 §3.6）。
inline double rhythm_quality(const std::vector<int>& curve) {
    int n = (int)curve.size();
    if (n < 4) return 0.0;
    int half = n / 2;
    double early = 0, late = 0;
    for (int i = 0; i < half; ++i) early += curve[i];
    for (int i = half; i < n; ++i) late += curve[i];
    early /= half;
    late /= (n - half);
    if (early < 1.0) return 0.0;
    double q = (early - late) / early;
    return q < 0.0 ? 0.0 : q;
}

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
        if (moves.empty()) {  // 死局：洗牌续玩（镜像真机 _settle_deadlock），洗不出来才真停
            reshuffle(g, rng, coat.empty() ? nullptr : &coat);
            moves = legal_moves(g, coat.empty() ? nullptr : &coat);
            if (moves.empty()) break;
        }
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
        if (moves.empty()) {  // 死局：洗牌续玩，洗不出来才真停
            reshuffle(g, rng, coat.empty() ? nullptr : &coat);
            moves = legal_moves(g, coat.empty() ? nullptr : &coat);
            if (moves.empty()) break;
        }
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
                    if (ms.empty()) {  // rollout 内也镜像洗牌（保真）
                        reshuffle(gc, rc);
                        ms = legal_moves(gc);
                        if (ms.empty()) break;
                    }
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
        if (moves.empty()) {  // 死局：洗牌续玩，洗不出来才真停
            reshuffle(g, rng, coat.empty() ? nullptr : &coat);
            moves = legal_moves(g, coat.empty() ? nullptr : &coat);
            if (moves.empty()) break;
        }
        res.solspace_curve.push_back((int)moves.size());  // 局内节奏：本步可选有效交换数
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
        if (moves.empty()) {  // 死局：洗牌续玩，洗不出来才真停
            reshuffle(g, rng, coat.empty() ? nullptr : &coat);
            moves = legal_moves(g, coat.empty() ? nullptr : &coat);
            if (moves.empty()) break;
        }
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
// 玩家画像：一套 move_value 权重 = 一类玩家（09 §3.5 启发权重 / §4.1 选民）。
struct Heuristic {
    const char* name = "?";
    double w_obj = 100.0;    // 目标进度权重
    double w_score = 0.01;   // 分数权重
    double w_cascade = 0.0;  // 连锁权重
};

// 按某画像给一步打分（目标进度统一折算成"件数"，分数/连锁另计）。
inline double heuristic_value(const ResolveResult& rr, const Level& lv, const Heuristic& h) {
    double prog = 0.0;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE) prog += rr.score / 100.0;
        else if (o.type == OBJ_COLLECT) {
            int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
            prog += g;
        } else if (o.type == OBJ_CLEAR_JELLY) prog += rr.jelly_cleared;
        else if (o.type == OBJ_CLEAR_BLOCKER) prog += rr.blocker_cleared;
    }
    return h.w_obj * prog + h.w_score * (double)rr.score + h.w_cascade * (double)rr.cascades;
}

// 按某画像玩一局（结构同 smart_greedy，选步用 heuristic_value(., h)）。
inline PlayResult heuristic_play(const Level& lv, const Heuristic& h) {
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
        if (moves.empty()) {  // 死局：洗牌续玩，洗不出来才真停
            reshuffle(g, rng, coat.empty() ? nullptr : &coat);
            moves = legal_moves(g, coat.empty() ? nullptr : &coat);
            if (moves.empty()) break;
        }
        res.solspace_curve.push_back((int)moves.size());  // 局内节奏：本步可选有效交换数
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
            double v = heuristic_value(rr, lv, h);
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

// 求解器组（选民）：几类不同画像的玩家。
inline std::vector<Heuristic> solver_panel() {
    return {
        {"rusher",   100.0, 0.01, 0.0},  // 目标至上
        {"scorer",   0.0,   1.0,  0.0},  // 只刷分（目标盲）
        {"cascader", 30.0,  0.5,  5.0},  // 爱连锁 + 兼顾目标
    };
}

// 一步是否"推进了当前目标"（任一目标有进展即算）。无目标 → 任何消除都算。
inline bool move_progresses(const ResolveResult& rr, const Level& lv) {
    if (lv.objectives.empty()) return rr.cleared > 0;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE && rr.score > 0) return true;
        if (o.type == OBJ_COLLECT) {
            int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
            if (g > 0) return true;
        }
        if (o.type == OBJ_CLEAR_JELLY && rr.jelly_cleared > 0) return true;
        if (o.type == OBJ_CLEAR_BLOCKER && rr.blocker_cleared > 0) return true;
    }
    return false;
}

// 精炼版局内节奏：用 rusher 玩一局，每步记录"能推进目标的合法交换数"。
// 目标关随障碍/果冻耗尽 → 该数自然递减(前松后紧)；冲分关 → 平。生成器分析用，不在热循环。
inline std::vector<int> objective_progress_curve(const Level& lv) {
    Heuristic h = solver_panel()[0];  // rusher
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    std::vector<int> curve;
    int moves_used = 0;
    int score = 0;
    while (moves_used < lv.move_limit
           && !objectives_met(lv, score, collected, jelly_total, blocker_total)) {
        auto moves = legal_moves(g, coat.empty() ? nullptr : &coat);
        if (moves.empty()) {  // 死局：洗牌续玩，洗不出来才真停
            reshuffle(g, rng, coat.empty() ? nullptr : &coat);
            moves = legal_moves(g, coat.empty() ? nullptr : &coat);
            if (moves.empty()) break;
        }
        // 数本步能推进目标的交换 + 同时按 rusher 选最佳步
        int prog = 0;
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
            if (move_progresses(rr, lv)) prog++;
            double v = heuristic_value(rr, lv, h);
            if (v > best_v) { best_v = v; best = m; }
        }
        curve.push_back(prog);
        swap_cells(g, best.a, best.b);
        ResolveResult rr = resolve(g, lv.species, rng,
                                   jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat);
        score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        moves_used++;
    }
    return curve;
}

struct LevelEval {
    double floor_score = 0;       // 随机玩家(地板)平均分
    double ceil_score = 0;        // 最强画像(天花板)平均分
    double lfhc_gap = 0;          // (ceil-floor)/floor
    double skilled_pass_rate = 0; // 最强画像通过率（可解性/难度反指标）
    double panel_pass = 0;        // 面板平均通过率（多档里多少能过=有多宽容）
    const char* difficulty = "?";
};

// 投票评估：地板(random) + 一组画像玩家各跑 trials 次，取均值投票。
inline LevelEval evaluate_level(const Level& base, int trials = 8) {
    auto panel = solver_panel();
    double floor_sum = 0;
    std::vector<double> a_score(panel.size(), 0.0);
    std::vector<int> a_wins(panel.size(), 0);
    for (int t = 0; t < trials; ++t) {
        Level lv = base;
        lv.seed = base.seed + (uint32_t)t * 1000003u;  // 每次试不同随机流
        floor_sum += random_play(lv).score;
        for (size_t i = 0; i < panel.size(); ++i) {
            PlayResult r = heuristic_play(lv, panel[i]);
            a_score[i] += r.score;
            if (r.won) a_wins[i]++;
        }
    }
    LevelEval e;
    e.floor_score = floor_sum / trials;
    double best_score = 0, best_pass = 0, pass_sum = 0;
    for (size_t i = 0; i < panel.size(); ++i) {
        double sc = a_score[i] / trials;
        double pa = (double)a_wins[i] / trials;
        if (sc > best_score) best_score = sc;
        if (pa > best_pass) best_pass = pa;
        pass_sum += pa;
    }
    e.ceil_score = best_score;
    e.lfhc_gap = (e.ceil_score - e.floor_score) / (e.floor_score < 1.0 ? 1.0 : e.floor_score);
    e.skilled_pass_rate = best_pass;
    e.panel_pass = pass_sum / panel.size();
    double p = e.skilled_pass_rate;
    e.difficulty = p > 0.8 ? "EASY" : p > 0.4 ? "MEDIUM" : p > 0.1 ? "HARD" : "EXPERT";
    return e;
}

}  // namespace me
