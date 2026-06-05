#pragma once
// solver.hpp — 求解器（09 §3）。求解器既是"玩家"也是"评估器"。
// v1：贪心玩家(地板代言人)。后续加 MCTS(天花板)、Beam、投票评估。
#include "match_engine.hpp"
#include <cstdint>

namespace me {

// ───────────── 巧克力蔓延 C++ 镜像（生成器/求解器专用，子命名空间隔离）─────────────
// 语义与 godot/core/match_engine.gd / board.gd 一一对应（巧克力压力源）：
//   占格、不参与 match、不可交换、不下落(gravity 固定切段)、相邻消除则啃掉一格(choco-1)；
//   玩家整步若零啃食 → 从现存巧克力格向随机正交相邻"可侵占格"增殖一格。
// 放进 gen_choco 子命名空间：与 match_engine.hpp 现有/未来的同名 choco 函数零重定义冲突，
//   且不触碰 match_engine.hpp（另有并行改动在该文件加 ingredient）。
namespace gen_choco {

// choco 感知匹配：巧克力格(choco>0)与锁住格(coat>0)同样不参与/不串连。
inline std::vector<Vec2> find_matches(const Grid& g,
                                      const std::vector<std::vector<int>>* coat,
                                      const std::vector<std::vector<int>>* choco) {
    int h = (int)g.size();
    if (h == 0) return {};
    int w = (int)g[0].size();
    auto blocked = [&](int x, int y) -> bool {
        return g[y][x] == EMPTY || g[y][x] == WALL
            || (coat && (*coat)[y][x] > 0) || (choco && (*choco)[y][x] > 0);
    };
    std::vector<std::vector<char>> mark(h, std::vector<char>(w, 0));
    for (int y = 0; y < h; ++y) {
        int x = 0;
        while (x < w) {
            if (blocked(x, y)) { ++x; continue; }
            int e = x;
            while (e + 1 < w && g[y][e + 1] == g[y][x] && !blocked(e + 1, y)) ++e;
            if (e - x + 1 >= 3)
                for (int k = x; k <= e; ++k) mark[y][k] = 1;
            x = e + 1;
        }
    }
    for (int x = 0; x < w; ++x) {
        int y = 0;
        while (y < h) {
            if (blocked(x, y)) { ++y; continue; }
            int e = y;
            while (e + 1 < h && g[e + 1][x] == g[y][x] && !blocked(x, e + 1)) ++e;
            if (e - y + 1 >= 3)
                for (int k = y; k <= e; ++k) mark[k][x] = 1;
            y = e + 1;
        }
    }
    std::vector<Vec2> out;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x)
            if (mark[y][x]) out.push_back({x, y});
    return out;
}

// choco 感知重力：巧克力格与墙/锁住格一样原地固定、把列切段。
inline void apply_gravity(Grid& g, const std::vector<std::vector<int>>* coat,
                          const std::vector<std::vector<int>>* choco) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    for (int x = 0; x < w; ++x) {
        int seg_start = 0;
        for (int y = 0; y <= h; ++y) {
            bool fixed = (y < h) && ((coat && (*coat)[y][x] > 0) || (choco && (*choco)[y][x] > 0));
            if (y == h || g[y][x] == WALL || fixed) {
                std::vector<int> stack;
                for (int k = seg_start; k < y; ++k)
                    if (g[k][x] != EMPTY) stack.push_back(g[k][x]);
                int seg_len = y - seg_start;
                int empties = seg_len - (int)stack.size();
                for (int k = seg_start; k < y; ++k) {
                    int idx = k - seg_start;
                    g[k][x] = (idx < empties) ? EMPTY : stack[idx - empties];
                }
                seg_start = y + 1;
            }
        }
    }
}

// choco 感知合法交换：巧克力格不可参与交换。
inline bool is_legal_swap(Grid& g, Vec2 a, Vec2 b,
                          const std::vector<std::vector<int>>* coat,
                          const std::vector<std::vector<int>>* choco) {
    if (std::abs(a.x - b.x) + std::abs(a.y - b.y) != 1) return false;
    int va = g[a.y][a.x], vb = g[b.y][b.x];
    if (va == WALL || vb == WALL || va == EMPTY || vb == EMPTY) return false;
    if (coat && ((*coat)[a.y][a.x] > 0 || (*coat)[b.y][b.x] > 0)) return false;
    if (choco && ((*choco)[a.y][a.x] > 0 || (*choco)[b.y][b.x] > 0)) return false;
    swap_cells(g, a, b);
    bool found = !find_matches(g, coat, choco).empty();
    swap_cells(g, a, b);
    return found;
}

// choco 感知死局判定。
inline bool has_legal_move(Grid& g, const std::vector<std::vector<int>>* coat,
                           const std::vector<std::vector<int>>* choco) {
    int h = (int)g.size();
    if (h == 0) return false;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && gen_choco::is_legal_swap(g, {x, y}, {x + 1, y}, coat, choco)) return true;
            if (y + 1 < h && gen_choco::is_legal_swap(g, {x, y}, {x, y + 1}, coat, choco)) return true;
        }
    return false;
}

// 啃食：被清除格(cleared)内或正交相邻的巧克力格 -1。返回啃掉数。
inline int eat_chocolate(std::vector<std::vector<int>>& choco, const std::vector<Vec2>& cleared) {
    int h = (int)choco.size();
    if (h == 0) return 0;
    int w = (int)choco[0].size();
    std::vector<std::vector<char>> cs(h, std::vector<char>(w, 0));
    for (const auto& p : cleared)
        if (p.x >= 0 && p.x < w && p.y >= 0 && p.y < h) cs[p.y][p.x] = 1;
    int eaten = 0;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (choco[y][x] <= 0) continue;
            bool hit = cs[y][x]
                || (x > 0 && cs[y][x - 1]) || (x + 1 < w && cs[y][x + 1])
                || (y > 0 && cs[y - 1][x]) || (y + 1 < h && cs[y + 1][x]);
            if (hit) { choco[y][x]--; ++eaten; }
        }
    return eaten;
}

// 数巧克力格总数。
inline int count_chocolate(const std::vector<std::vector<int>>& choco) {
    int n = 0;
    for (const auto& row : choco)
        for (int v : row)
            if (v > 0) ++n;
    return n;
}

// 蔓延：从现存巧克力格的随机正交相邻"可侵占格"(普通棋子 species>=0、非墙非空、choco==0)选一变巧克力。
//   候选枚举序固定(行→列→四向右左下上)，注入 rng → 确定性。无处可蔓延返回 false。
inline bool spread_chocolate(std::vector<std::vector<int>>& choco, const Grid& g, std::mt19937& rng) {
    int h = (int)choco.size();
    if (h == 0) return false;
    int w = (int)choco[0].size();
    static const int dx[4] = {1, -1, 0, 0};
    static const int dy[4] = {0, 0, 1, -1};
    std::vector<std::vector<char>> seen(h, std::vector<char>(w, 0));
    std::vector<Vec2> candidates;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (choco[y][x] <= 0) continue;
            for (int d = 0; d < 4; ++d) {
                int nx = x + dx[d], ny = y + dy[d];
                if (nx < 0 || nx >= w || ny < 0 || ny >= h) continue;
                if (choco[ny][nx] > 0) continue;
                if (g[ny][nx] < 0) continue;   // EMPTY(-1)/WALL(-2) 不可侵占
                if (seen[ny][nx]) continue;
                seen[ny][nx] = 1;
                candidates.push_back({nx, ny});
            }
        }
    if (candidates.empty()) return false;
    std::uniform_int_distribution<int> dist(0, (int)candidates.size() - 1);
    Vec2 pick = candidates[dist(rng)];
    choco[pick.y][pick.x] = 1;
    return true;
}

struct ChocoResolveResult {
    int score = 0, cascades = 0, cleared = 0;
    int jelly_cleared = 0, blocker_cleared = 0, choco_cleared = 0;
    std::vector<int> by_species;
};

// choco 感知 resolve：消除→破锁/啃巧克力→计分→下落(障碍固定)→补充，循环至稳定。
inline ChocoResolveResult resolve(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                                  std::vector<std::vector<int>>* jelly,
                                  std::vector<std::vector<int>>* coat,
                                  std::vector<std::vector<int>>* choco,
                                  std::vector<std::deque<int>>* feed, bool do_refill) {
    ChocoResolveResult r;
    while (true) {
        auto matched = find_matches(g, coat, choco);
        if (matched.empty()) break;
        r.cascades++;
        int H = (int)g.size(), W = (int)g[0].size();
        std::vector<std::vector<char>> ism(H, std::vector<char>(W, 0));
        for (const auto& p : matched) ism[p.y][p.x] = 1;
        if (coat) {
            for (int y = 0; y < H; ++y)
                for (int x = 0; x < W; ++x) {
                    if ((*coat)[y][x] <= 0) continue;
                    bool hit = ism[y][x]
                        || (x > 0 && ism[y][x - 1]) || (x + 1 < W && ism[y][x + 1])
                        || (y > 0 && ism[y - 1][x]) || (y + 1 < H && ism[y + 1][x]);
                    if (hit) { (*coat)[y][x]--; r.blocker_cleared++; }
                }
        }
        if (choco) r.choco_cleared += gen_choco::eat_chocolate(*choco, matched);
        for (const auto& p : matched) {
            int s = g[p.y][p.x];
            if (s >= 0) {
                if ((int)r.by_species.size() <= s) r.by_species.resize(s + 1, 0);
                r.by_species[s]++;
            }
            if (jelly && (*jelly)[p.y][p.x] > 0) { (*jelly)[p.y][p.x]--; r.jelly_cleared++; }
            g[p.y][p.x] = EMPTY;
        }
        r.cleared += (int)matched.size();
        r.score += score_for_clear((int)matched.size(), r.cascades);
        apply_gravity(g, coat, choco);
        if (do_refill) refill(g, species, rng, feed);
    }
    return r;
}

// choco 感知洗牌：仅打乱普通棋子(非墙/空/锁/巧克力)，直到无现成消除且有 choco 感知合法步。
inline void reshuffle(Grid& g, std::mt19937& rng,
                      const std::vector<std::vector<int>>* coat,
                      const std::vector<std::vector<int>>* choco) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    std::vector<Vec2> positions;
    std::vector<int> tiles;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            int v = g[y][x];
            if (v == WALL || v == EMPTY) continue;
            if (coat && (*coat)[y][x] > 0) continue;    // 锁住格不参与洗牌
            if (choco && (*choco)[y][x] > 0) continue;  // 巧克力格不参与洗牌
            positions.push_back({x, y});
            tiles.push_back(v);
        }
    bool have_safe = false;
    std::vector<int> safe_tiles;
    for (int attempt = 0; attempt < 100; ++attempt) {
        for (int i = (int)tiles.size() - 1; i > 0; --i) {
            std::uniform_int_distribution<int> d(0, i);
            std::swap(tiles[(size_t)i], tiles[(size_t)d(rng)]);
        }
        for (size_t i = 0; i < positions.size(); ++i)
            g[positions[i].y][positions[i].x] = tiles[i];
        bool no_match = find_matches(g, coat, choco).empty();
        if (no_match && has_legal_move(g, coat, choco)) return;
        if (no_match && !have_safe) { have_safe = true; safe_tiles = tiles; }
    }
    if (have_safe)
        for (size_t i = 0; i < positions.size(); ++i)
            g[positions[i].y][positions[i].x] = safe_tiles[i];
}

}  // namespace gen_choco

enum ObjType { OBJ_SCORE, OBJ_COLLECT, OBJ_CLEAR_JELLY, OBJ_CLEAR_BLOCKER, OBJ_CLEAR_CHOCO, OBJ_COLLECT_INGREDIENT };

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
    std::vector<std::vector<int>> choco;        // 巧克力层（蔓延压力源，choco[y][x]=1=巧克力格，可选）
    std::vector<std::vector<int>> ing;          // 原料层（运料关，ing[y][x]=1=原料格，随重力下落、不可消不可换，可选）
    std::vector<int> exit_cols;                 // 出口列（运料关，物理最底行这些列为出口，原料沉到出口被收集）
    bool is_scrolling = false;                  // 滚动/挖矿关：胜利=挖穿 feed（非分数/目标）
    std::vector<std::deque<int>> feed;          // 每列预设补充队列（长盘深层内容，refill 从前端出）
};

// 把一次消除的 by_species 累加进总收集表。
inline void accumulate(std::vector<int>& acc, const std::vector<int>& add) {
    if (acc.size() < add.size()) acc.resize(add.size(), 0);
    for (size_t i = 0; i < add.size(); ++i) acc[i] += add[i];
}

// 是否过关：objectives 为空 → 旧式 score>=target_score；否则全部目标满足。
inline bool objectives_met(const Level& lv, int score, const std::vector<int>& collected,
                           int jelly_cleared = 0, int blocker_cleared = 0, int choco_cleared = 0,
                           int ingredient_collected = 0) {
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
        } else if (o.type == OBJ_CLEAR_CHOCO) {
            if (choco_cleared < o.target) return false;
        } else if (o.type == OBJ_COLLECT_INGREDIENT) {
            if (ingredient_collected < o.target) return false;
        }
    }
    return true;
}

// 滚动关：feed 全空 = 长盘挖穿 = 通关。
inline bool feed_drained(const std::vector<std::deque<int>>& feed) {
    for (const auto& c : feed) if (!c.empty()) return false;
    return true;
}

// 滚动关：当前页已清到≥70%(空格占非墙格 ≥70%)。
inline bool scroll_cleared_enough(const Grid& g) {
    int total = 0, empty = 0;
    for (const auto& row : g)
        for (int v : row) {
            if (v == WALL) continue;
            total++;
            if (v == EMPTY) empty++;
        }
    return total > 0 && empty * 10 >= 7 * total;
}

// 滚动关每步收口：清到一页70% → 拉新页(从 feed 批量补满空格) + 结算级联(仍只挖空)。
// feed 已空又清到70% = 储备挖光 → dug=true(挖穿)。返回拉新页带来的额外结算。
inline ResolveResult scroll_advance(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                                    std::vector<std::deque<int>>& feed,
                                    std::vector<std::vector<int>>* jelly,
                                    std::vector<std::vector<int>>* coat, bool& dug) {
    ResolveResult none;
    if (dug || !scroll_cleared_enough(g)) return none;
    if (feed_drained(feed)) { dug = true; return none; }   // 储备空+清70% = 挖穿
    refill(g, species, rng, &feed);                        // 拉新页：批量补满空格(feed 不足列留空)
    return resolve(g, species, rng, jelly, coat, &feed, false);  // 拉下来只结算级联，不再补
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
    int choco_cleared = 0;       // 累计啃掉的巧克力格
    int ingredient_collected = 0;  // 累计落到出口被收的原料数（运料关）
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
    if (lv.is_scrolling) return 100.0 * rr.cleared + 0.01 * rr.score;  // 挖矿：消得越多=挖得越深(feed 下流量)
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

// 一步交换的"价值"（choco 关）：CLEAR_CHOCO→啃的巧克力数×W；其余目标同 move_value 口径。
inline double move_value_choco(const gen_choco::ChocoResolveResult& rr, const Level& lv) {
    if (lv.objectives.empty()) return (double)rr.score;
    const double W = 100.0;
    double v = 0.0;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE) v += rr.score;
        else if (o.type == OBJ_COLLECT) {
            int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
            v += W * g;
        } else if (o.type == OBJ_CLEAR_JELLY) v += W * rr.jelly_cleared;
        else if (o.type == OBJ_CLEAR_BLOCKER) v += W * rr.blocker_cleared;
        else if (o.type == OBJ_CLEAR_CHOCO) v += W * rr.choco_cleared;
    }
    v += 0.01 * rr.score;
    return v;
}

// 一步是否"推进巧克力目标"（choco 关 progress 曲线用）。
inline bool move_progresses_choco(const gen_choco::ChocoResolveResult& rr, const Level& lv) {
    if (lv.objectives.empty()) return rr.cleared > 0;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE && rr.score > 0) return true;
        if (o.type == OBJ_COLLECT) {
            int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
            if (g > 0) return true;
        }
        if (o.type == OBJ_CLEAR_JELLY && rr.jelly_cleared > 0) return true;
        if (o.type == OBJ_CLEAR_BLOCKER && rr.blocker_cleared > 0) return true;
        if (o.type == OBJ_CLEAR_CHOCO && rr.choco_cleared > 0) return true;
    }
    return false;
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

// choco 感知枚举合法交换。
inline std::vector<Move> legal_moves_choco(Grid& g, const std::vector<std::vector<int>>* coat,
                                           const std::vector<std::vector<int>>* choco) {
    std::vector<Move> out;
    int h = (int)g.size();
    if (h == 0) return out;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && gen_choco::is_legal_swap(g, {x, y}, {x + 1, y}, coat, choco))
                out.push_back({{x, y}, {x + 1, y}});
            if (y + 1 < h && gen_choco::is_legal_swap(g, {x, y}, {x, y + 1}, coat, choco))
                out.push_back({{x, y}, {x, y + 1}});
        }
    return out;
}

// ───────────── 运料关求解辅助（ing 感知）─────────────
// 直接复用 match_engine.hpp 顶层的 *_ingredient 镜像（find_matches_ingredient / apply_gravity_ingredient /
//   is_legal_swap_ingredient / resolve_ingredient / drain_ingredients），不像 choco 那样另起子命名空间——
//   因 ing 系列带 _ingredient 后缀无重名冲突。这里只补 match_engine 未提供的 ing 感知"枚举/死局/洗牌"三件套。

// ing 感知枚举合法交换：原料格不可参与交换。
inline std::vector<Move> legal_moves_ingredient(Grid& g,
                                                const std::vector<std::vector<int>>* coat,
                                                const std::vector<std::vector<int>>* choco,
                                                const std::vector<std::vector<int>>* ing) {
    std::vector<Move> out;
    int h = (int)g.size();
    if (h == 0) return out;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && is_legal_swap_ingredient(g, {x, y}, {x + 1, y}, coat, choco, ing))
                out.push_back({{x, y}, {x + 1, y}});
            if (y + 1 < h && is_legal_swap_ingredient(g, {x, y}, {x, y + 1}, coat, choco, ing))
                out.push_back({{x, y}, {x, y + 1}});
        }
    return out;
}

// ing 感知死局判定。
inline bool has_legal_move_ingredient(Grid& g, const std::vector<std::vector<int>>* coat,
                                      const std::vector<std::vector<int>>* choco,
                                      const std::vector<std::vector<int>>* ing) {
    int h = (int)g.size();
    if (h == 0) return false;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && is_legal_swap_ingredient(g, {x, y}, {x + 1, y}, coat, choco, ing)) return true;
            if (y + 1 < h && is_legal_swap_ingredient(g, {x, y}, {x, y + 1}, coat, choco, ing)) return true;
        }
    return false;
}

// ing 感知洗牌：仅打乱普通棋子（非墙/空/锁/巧克力/原料），直到无现成消除且有 ing 感知合法步。
inline void reshuffle_ingredient(Grid& g, std::mt19937& rng,
                                 const std::vector<std::vector<int>>* coat,
                                 const std::vector<std::vector<int>>* choco,
                                 const std::vector<std::vector<int>>* ing) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    std::vector<Vec2> positions;
    std::vector<int> tiles;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            int v = g[y][x];
            if (v == WALL || v == EMPTY) continue;
            if (coat && (*coat)[y][x] > 0) continue;
            if (choco && (*choco)[y][x] > 0) continue;
            if (ing && (*ing)[y][x] > 0) continue;   // 原料格不参与洗牌（它是可动元素但不可换/不可消）
            positions.push_back({x, y});
            tiles.push_back(v);
        }
    bool have_safe = false;
    std::vector<int> safe_tiles;
    for (int attempt = 0; attempt < 100; ++attempt) {
        for (int i = (int)tiles.size() - 1; i > 0; --i) {
            std::uniform_int_distribution<int> d(0, i);
            std::swap(tiles[(size_t)i], tiles[(size_t)d(rng)]);
        }
        for (size_t i = 0; i < positions.size(); ++i)
            g[positions[i].y][positions[i].x] = tiles[i];
        bool no_match = find_matches_ingredient(g, coat, choco, ing).empty();
        if (no_match && has_legal_move_ingredient(g, coat, choco, ing)) return;
        if (no_match && !have_safe) { have_safe = true; safe_tiles = tiles; }
    }
    if (have_safe)
        for (size_t i = 0; i < positions.size(); ++i)
            g[positions[i].y][positions[i].x] = safe_tiles[i];
}

// 原料下沉势能：剩余原料的行号之和（越靠下 y 越大、越接近底部出口行）。
//   运料关进度信号天然稀疏（原料没沉到出口=收集进度 0），加这项中间激励让玩家主动消除原料下方棋子、
//   把原料一格格往出口推——否则贪心/画像玩家会无视未到底的原料、退化成纯刷分（实测 target=N 时 pass≡0）。
//   权重远小于"收集一个"(value W=100)：收集净收益始终为正(收 1 个失最多 H-1 行势能仍远赚)，故不会卡着不收。
inline double ingredient_sink_bonus(const std::vector<std::vector<int>>& ing) {
    if (ing.empty()) return 0.0;
    double sy = 0.0;
    for (size_t y = 0; y < ing.size(); ++y)
        for (int v : ing[y])
            if (v > 0) sy += (double)y;
    return 2.0 * sy;
}

// 一步交换的"价值"（运料关）：OBJ_COLLECT_INGREDIENT → 本步收的原料数×W；其余目标同 move_value 口径。
inline double move_value_ingredient(const IngResolveResult& rr, const Level& lv) {
    if (lv.objectives.empty()) return (double)rr.score;
    const double W = 100.0;
    double v = 0.0;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE) v += rr.score;
        else if (o.type == OBJ_COLLECT) {
            int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
            v += W * g;
        } else if (o.type == OBJ_CLEAR_JELLY) v += W * rr.jelly_cleared;
        else if (o.type == OBJ_CLEAR_BLOCKER) v += W * rr.blocker_cleared;
        else if (o.type == OBJ_COLLECT_INGREDIENT) v += W * rr.ingredient_collected;
    }
    v += 0.01 * rr.score;
    return v;
}

// 一步是否"推进运料目标"（运料关 progress 曲线用）。
inline bool move_progresses_ingredient(const IngResolveResult& rr, const Level& lv) {
    if (lv.objectives.empty()) return rr.cleared > 0;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE && rr.score > 0) return true;
        if (o.type == OBJ_COLLECT) {
            int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
            if (g > 0) return true;
        }
        if (o.type == OBJ_CLEAR_JELLY && rr.jelly_cleared > 0) return true;
        if (o.type == OBJ_CLEAR_BLOCKER && rr.blocker_cleared > 0) return true;
        if (o.type == OBJ_COLLECT_INGREDIENT && rr.ingredient_collected > 0) return true;
    }
    return false;
}

// ───────────── choco 关统一玩家循环（5 类玩家共享回合骨架，选步策略由 value_fn 注入）─────────────
// 镜像 board.gd：换子 → resolve_choco(整步啃食) → 整步零啃食则 spread_chocolate 蔓延一格 → 死局 choco 感知洗牌。
// value_fn(ChocoResolveResult, Level) → 该步价值；record_curve=true 时记录"能推进目标的交换数"曲线。
template <typename ValueFn>
inline PlayResult play_choco(const Level& lv, ValueFn value_fn, bool record_curve) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    std::vector<std::vector<int>> coat = lv.coat;
    std::vector<std::vector<int>> choco = lv.choco;
    int jelly_total = 0, blocker_total = 0, choco_total = 0;
    auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
    auto chocop = [&]() { return choco.empty() ? nullptr : &choco; };
    while (res.moves_used < lv.move_limit
           && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, choco_total)) {
        auto moves = legal_moves_choco(g, coatp(), chocop());
        if (moves.empty()) {  // 死局：choco 感知洗牌续玩
            gen_choco::reshuffle(g, rng, coatp(), chocop());
            moves = legal_moves_choco(g, coatp(), chocop());
            if (moves.empty()) break;
        }
        if (record_curve) res.solspace_curve.push_back((int)moves.size());
        double best_v = -1e18;
        Move best = moves[0];
        for (const auto& m : moves) {
            Grid gc = g;
            std::mt19937 rc = rng;
            std::vector<std::vector<int>> jc = jelly, cc = coat, hc = choco;
            swap_cells(gc, m.a, m.b);
            gen_choco::ChocoResolveResult rr = gen_choco::resolve(
                gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                hc.empty() ? nullptr : &hc, nullptr, true);
            double v = value_fn(rr, lv);
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        gen_choco::ChocoResolveResult rr = gen_choco::resolve(
            g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
            choco.empty() ? nullptr : &choco, nullptr, true);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        choco_total += rr.choco_cleared;
        if (!choco.empty() && rr.choco_cleared == 0)  // 整步零啃食 → 蔓延一格（镜像 _spread_choco_if_untouched）
            gen_choco::spread_chocolate(choco, g, rng);
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.choco_cleared = choco_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total, choco_total);
    return res;
}

// ───────────── 运料关统一玩家循环（各类玩家共享回合骨架，选步策略由 value_fn 注入）─────────────
// 镜像 board.gd：换子 → resolve_ingredient（消除→原料随重力下落→沉到出口收集）→ 死局 ing 感知洗牌。
//   与 choco 不同：原料不蔓延、随重力可动；胜利=累计 ingredient_collected 达标。exit_cols 来自 lv。
// value_fn(IngResolveResult, Level) → 该步价值；record_curve=true 时记录"可选有效交换数"曲线。
template <typename ValueFn>
inline PlayResult play_ingredient(const Level& lv, ValueFn value_fn, bool record_curve) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    std::vector<std::vector<int>> coat = lv.coat;
    std::vector<std::vector<int>> choco = lv.choco;
    std::vector<std::vector<int>> ing = lv.ing;
    int jelly_total = 0, blocker_total = 0, ing_total = 0;
    auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
    auto chocop = [&]() { return choco.empty() ? nullptr : &choco; };
    auto ingp = [&]() { return ing.empty() ? nullptr : &ing; };
    while (res.moves_used < lv.move_limit
           && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, ing_total)) {
        auto moves = legal_moves_ingredient(g, coatp(), chocop(), ingp());
        if (moves.empty()) {  // 死局：ing 感知洗牌续玩
            reshuffle_ingredient(g, rng, coatp(), chocop(), ingp());
            moves = legal_moves_ingredient(g, coatp(), chocop(), ingp());
            if (moves.empty()) break;
        }
        if (record_curve) res.solspace_curve.push_back((int)moves.size());
        double best_v = -1e18;
        Move best = moves[0];
        for (const auto& m : moves) {
            Grid gc = g;
            std::mt19937 rc = rng;
            std::vector<std::vector<int>> jc = jelly, cc = coat, hc = choco, ic = ing;
            swap_cells(gc, m.a, m.b);
            IngResolveResult rr = resolve_ingredient(
                gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                hc.empty() ? nullptr : &hc, ic.empty() ? nullptr : &ic, lv.exit_cols, nullptr, true);
            double v = value_fn(rr, lv) + ingredient_sink_bonus(ic);  // 收集价值 + 把原料推向出口的下沉势能
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        IngResolveResult rr = resolve_ingredient(
            g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
            choco.empty() ? nullptr : &choco, ing.empty() ? nullptr : &ing, lv.exit_cols, nullptr, true);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        ing_total += rr.ingredient_collected;
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.ingredient_collected = ing_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, ing_total);
    return res;
}

// 贪心玩家：每步选"立即得分最高"的交换。代表不规划的休闲玩家=地板。
inline PlayResult greedy_play(const Level& lv) {
    if (!lv.ing.empty())  // 运料关：走 ing 回合骨架，选步仍按立即分数（休闲玩家=地板，不主动运料）
        return play_ingredient(lv, [](const IngResolveResult& rr, const Level&) {
            return (double)rr.score; }, false);
    if (!lv.choco.empty())  // 巧克力关：走 choco 回合骨架，选步仍按立即分数（休闲玩家）
        return play_choco(lv, [](const gen_choco::ChocoResolveResult& rr, const Level&) {
            return (double)rr.score; }, false);
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    std::vector<std::deque<int>> feed = lv.feed;  // 滚动关：补充队列(本局消耗)
    bool dug = false;  // 滚动关：挖穿标志(清到一页70%且储备空)
    while (res.moves_used < lv.move_limit && !(lv.is_scrolling ? dug : objectives_met(lv, res.score, collected, jelly_total, blocker_total))) {
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
            int gain = resolve(gc, lv.species, rc, nullptr, nullptr, nullptr, !lv.is_scrolling).score;
            if (gain > best_gain) {
                best_gain = gain;
                best = m;
            }
        }
        swap_cells(g, best.a, best.b);
        ResolveResult rr = resolve(g, lv.species, rng, jelly.empty() ? nullptr : &jelly,
                                   coat.empty() ? nullptr : &coat, nullptr, !lv.is_scrolling);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        if (lv.is_scrolling) {  // 每步收口：清到一页70%→拉新页/挖穿
            ResolveResult pr = scroll_advance(g, lv.species, rng, feed,
                jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat, dug);
            res.score += pr.score;
            accumulate(collected, pr.by_species);
            jelly_total += pr.jelly_cleared;
            blocker_total += pr.blocker_cleared;
        }
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.won = (lv.is_scrolling ? dug : objectives_met(lv, res.score, collected, jelly_total, blocker_total));
    return res;
}

// 目标感知贪心：每步选"朝目标推进最多"的交换（move_value），而非最大分。
// 这是真正"会玩这关的高手" = 可信天花板。候选评估带 jelly/coat 拷贝以量出目标进度。
inline PlayResult smart_greedy_play(const Level& lv) {
    if (!lv.ing.empty())  // 运料关：ing 回合骨架 + 目标感知选步（COLLECT_INGREDIENT 追运料下沉收集）
        return play_ingredient(lv, move_value_ingredient, true);
    if (!lv.choco.empty())  // 巧克力关：choco 回合骨架 + 目标感知选步（CLEAR_CHOCO 追啃食）
        return play_choco(lv, move_value_choco, true);
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    std::vector<std::deque<int>> feed = lv.feed;  // 滚动关：补充队列(本局消耗)
    bool dug = false;  // 滚动关：挖穿标志(清到一页70%且储备空)
    while (res.moves_used < lv.move_limit
           && !(lv.is_scrolling ? dug : objectives_met(lv, res.score, collected, jelly_total, blocker_total))) {
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
                                       jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                                       nullptr, !lv.is_scrolling);
            double v = move_value(rr, lv);
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        ResolveResult rr = resolve(g, lv.species, rng,
                                   jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                                   nullptr, !lv.is_scrolling);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        if (lv.is_scrolling) {  // 每步收口：清到一页70%→拉新页/挖穿
            ResolveResult pr = scroll_advance(g, lv.species, rng, feed,
                jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat, dug);
            res.score += pr.score;
            accumulate(collected, pr.by_species);
            jelly_total += pr.jelly_cleared;
            blocker_total += pr.blocker_cleared;
        }
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.won = (lv.is_scrolling ? dug : objectives_met(lv, res.score, collected, jelly_total, blocker_total));
    return res;
}

// 随机玩家：每步随便选一个合法交换。真正的"无脑休闲玩家" = 地板下沿。
inline PlayResult random_play(const Level& lv) {
    if (!lv.ing.empty()) {  // 运料关：ing 回合骨架 + 随机选步（地板代言人，靠运气运料）
        Grid g = lv.init_board;
        std::mt19937 rng(lv.seed);
        PlayResult res;
        std::vector<int> collected;
        std::vector<std::vector<int>> jelly = lv.jelly, coat = lv.coat, choco = lv.choco, ing = lv.ing;
        int jelly_total = 0, blocker_total = 0, ing_total = 0;
        auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
        auto chocop = [&]() { return choco.empty() ? nullptr : &choco; };
        auto ingp = [&]() { return ing.empty() ? nullptr : &ing; };
        while (res.moves_used < lv.move_limit
               && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, ing_total)) {
            auto moves = legal_moves_ingredient(g, coatp(), chocop(), ingp());
            if (moves.empty()) {
                reshuffle_ingredient(g, rng, coatp(), chocop(), ingp());
                moves = legal_moves_ingredient(g, coatp(), chocop(), ingp());
                if (moves.empty()) break;
            }
            Move m = moves[rng() % moves.size()];
            swap_cells(g, m.a, m.b);
            IngResolveResult rr = resolve_ingredient(
                g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                choco.empty() ? nullptr : &choco, ing.empty() ? nullptr : &ing, lv.exit_cols, nullptr, true);
            res.score += rr.score;
            accumulate(collected, rr.by_species);
            jelly_total += rr.jelly_cleared;
            blocker_total += rr.blocker_cleared;
            ing_total += rr.ingredient_collected;
            res.moves_used++;
        }
        res.collected = collected;
        res.jelly_cleared = jelly_total;
        res.blocker_cleared = blocker_total;
        res.ingredient_collected = ing_total;
        res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, ing_total);
        return res;
    }
    if (!lv.choco.empty()) {  // 巧克力关：choco 回合骨架 + 随机选步（地板代言人）
        Grid g = lv.init_board;
        std::mt19937 rng(lv.seed);
        PlayResult res;
        std::vector<int> collected;
        std::vector<std::vector<int>> jelly = lv.jelly, coat = lv.coat, choco = lv.choco;
        int jelly_total = 0, blocker_total = 0, choco_total = 0;
        auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
        auto chocop = [&]() { return choco.empty() ? nullptr : &choco; };
        while (res.moves_used < lv.move_limit
               && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, choco_total)) {
            auto moves = legal_moves_choco(g, coatp(), chocop());
            if (moves.empty()) {
                gen_choco::reshuffle(g, rng, coatp(), chocop());
                moves = legal_moves_choco(g, coatp(), chocop());
                if (moves.empty()) break;
            }
            Move m = moves[rng() % moves.size()];
            swap_cells(g, m.a, m.b);
            gen_choco::ChocoResolveResult rr = gen_choco::resolve(
                g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                choco.empty() ? nullptr : &choco, nullptr, true);
            res.score += rr.score;
            accumulate(collected, rr.by_species);
            jelly_total += rr.jelly_cleared;
            blocker_total += rr.blocker_cleared;
            choco_total += rr.choco_cleared;
            if (!choco.empty() && rr.choco_cleared == 0)  // 整步零啃食 → 蔓延一格
                gen_choco::spread_chocolate(choco, g, rng);
            res.moves_used++;
        }
        res.collected = collected;
        res.jelly_cleared = jelly_total;
        res.blocker_cleared = blocker_total;
        res.choco_cleared = choco_total;
        res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total, choco_total);
        return res;
    }
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    std::vector<std::deque<int>> feed = lv.feed;  // 滚动关：补充队列(本局消耗)
    bool dug = false;  // 滚动关：挖穿标志(清到一页70%且储备空)
    while (res.moves_used < lv.move_limit && !(lv.is_scrolling ? dug : objectives_met(lv, res.score, collected, jelly_total, blocker_total))) {
        auto moves = legal_moves(g, coat.empty() ? nullptr : &coat);
        if (moves.empty()) {  // 死局：洗牌续玩，洗不出来才真停
            reshuffle(g, rng, coat.empty() ? nullptr : &coat);
            moves = legal_moves(g, coat.empty() ? nullptr : &coat);
            if (moves.empty()) break;
        }
        Move m = moves[rng() % moves.size()];
        swap_cells(g, m.a, m.b);
        ResolveResult rr = resolve(g, lv.species, rng, jelly.empty() ? nullptr : &jelly,
                                   coat.empty() ? nullptr : &coat, nullptr, !lv.is_scrolling);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        if (lv.is_scrolling) {  // 每步收口：清到一页70%→拉新页/挖穿
            ResolveResult pr = scroll_advance(g, lv.species, rng, feed,
                jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat, dug);
            res.score += pr.score;
            accumulate(collected, pr.by_species);
            jelly_total += pr.jelly_cleared;
            blocker_total += pr.blocker_cleared;
        }
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.won = (lv.is_scrolling ? dug : objectives_met(lv, res.score, collected, jelly_total, blocker_total));
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
    if (lv.is_scrolling) prog = rr.cleared / 10.0;  // 挖矿：进度=消除格数(=feed 下流量)
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
    if (!lv.ing.empty())  // 运料关：ing 回合骨架 + 画像选步（目标进度含 ingredient_collected）
        return play_ingredient(lv, [&h](const IngResolveResult& rr, const Level& l) {
            double prog = 0.0;
            for (const auto& o : l.objectives) {
                if (o.type == OBJ_SCORE) prog += rr.score / 100.0;
                else if (o.type == OBJ_COLLECT) {
                    int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
                    prog += g;
                } else if (o.type == OBJ_CLEAR_JELLY) prog += rr.jelly_cleared;
                else if (o.type == OBJ_CLEAR_BLOCKER) prog += rr.blocker_cleared;
                else if (o.type == OBJ_COLLECT_INGREDIENT) prog += rr.ingredient_collected;
            }
            return h.w_obj * prog + h.w_score * (double)rr.score + h.w_cascade * (double)rr.cascades;
        }, true);
    if (!lv.choco.empty())  // 巧克力关：choco 回合骨架 + 画像选步（目标进度含 choco_cleared）
        return play_choco(lv, [&h](const gen_choco::ChocoResolveResult& rr, const Level& l) {
            double prog = 0.0;
            for (const auto& o : l.objectives) {
                if (o.type == OBJ_SCORE) prog += rr.score / 100.0;
                else if (o.type == OBJ_COLLECT) {
                    int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
                    prog += g;
                } else if (o.type == OBJ_CLEAR_JELLY) prog += rr.jelly_cleared;
                else if (o.type == OBJ_CLEAR_BLOCKER) prog += rr.blocker_cleared;
                else if (o.type == OBJ_CLEAR_CHOCO) prog += rr.choco_cleared;
            }
            return h.w_obj * prog + h.w_score * (double)rr.score + h.w_cascade * (double)rr.cascades;
        }, true);
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    int jelly_total = 0;
    std::vector<std::vector<int>> coat = lv.coat;
    int blocker_total = 0;
    std::vector<std::deque<int>> feed = lv.feed;  // 滚动关：补充队列(本局消耗)
    bool dug = false;  // 滚动关：挖穿标志(清到一页70%且储备空)
    while (res.moves_used < lv.move_limit
           && !(lv.is_scrolling ? dug : objectives_met(lv, res.score, collected, jelly_total, blocker_total))) {
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
                                       jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                                       nullptr, !lv.is_scrolling);
            double v = heuristic_value(rr, lv, h);
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        ResolveResult rr = resolve(g, lv.species, rng,
                                   jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                                   nullptr, !lv.is_scrolling);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        if (lv.is_scrolling) {  // 每步收口：清到一页70%→拉新页/挖穿
            ResolveResult pr = scroll_advance(g, lv.species, rng, feed,
                jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat, dug);
            res.score += pr.score;
            accumulate(collected, pr.by_species);
            jelly_total += pr.jelly_cleared;
            blocker_total += pr.blocker_cleared;
        }
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.won = (lv.is_scrolling ? dug : objectives_met(lv, res.score, collected, jelly_total, blocker_total));
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
    if (!lv.ing.empty()) {  // 运料关：rusher 选步，记录每步"能推进运料目标的交换数"
        Grid g = lv.init_board;
        std::mt19937 rng(lv.seed);
        std::vector<int> collected;
        std::vector<std::vector<int>> jelly = lv.jelly, coat = lv.coat, choco = lv.choco, ing = lv.ing;
        int jelly_total = 0, blocker_total = 0, ing_total = 0, score = 0, moves_used = 0;
        std::vector<int> curve;
        auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
        auto chocop = [&]() { return choco.empty() ? nullptr : &choco; };
        auto ingp = [&]() { return ing.empty() ? nullptr : &ing; };
        while (moves_used < lv.move_limit
               && !objectives_met(lv, score, collected, jelly_total, blocker_total, 0, ing_total)) {
            auto moves = legal_moves_ingredient(g, coatp(), chocop(), ingp());
            if (moves.empty()) {
                reshuffle_ingredient(g, rng, coatp(), chocop(), ingp());
                moves = legal_moves_ingredient(g, coatp(), chocop(), ingp());
                if (moves.empty()) break;
            }
            int prog = 0;
            double best_v = -1e18;
            Move best = moves[0];
            for (const auto& m : moves) {
                Grid gc = g;
                std::mt19937 rc = rng;
                std::vector<std::vector<int>> jc = jelly, cc = coat, hc = choco, ic = ing;
                swap_cells(gc, m.a, m.b);
                IngResolveResult rr = resolve_ingredient(
                    gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                    hc.empty() ? nullptr : &hc, ic.empty() ? nullptr : &ic, lv.exit_cols, nullptr, true);
                if (move_progresses_ingredient(rr, lv)) prog++;
                double prog_h = 0.0;
                for (const auto& o : lv.objectives)
                    if (o.type == OBJ_COLLECT_INGREDIENT) prog_h += rr.ingredient_collected;
                double v = h.w_obj * prog_h + h.w_score * (double)rr.score;
                if (v > best_v) { best_v = v; best = m; }
            }
            curve.push_back(prog);
            swap_cells(g, best.a, best.b);
            IngResolveResult rr = resolve_ingredient(
                g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                choco.empty() ? nullptr : &choco, ing.empty() ? nullptr : &ing, lv.exit_cols, nullptr, true);
            score += rr.score;
            accumulate(collected, rr.by_species);
            jelly_total += rr.jelly_cleared;
            blocker_total += rr.blocker_cleared;
            ing_total += rr.ingredient_collected;
            moves_used++;
        }
        return curve;
    }
    if (!lv.choco.empty()) {  // 巧克力关：rusher 选步，记录每步"能推进 choco 目标的交换数"
        Grid g = lv.init_board;
        std::mt19937 rng(lv.seed);
        std::vector<int> collected;
        std::vector<std::vector<int>> jelly = lv.jelly, coat = lv.coat, choco = lv.choco;
        int jelly_total = 0, blocker_total = 0, choco_total = 0, score = 0, moves_used = 0;
        std::vector<int> curve;
        auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
        auto chocop = [&]() { return choco.empty() ? nullptr : &choco; };
        while (moves_used < lv.move_limit
               && !objectives_met(lv, score, collected, jelly_total, blocker_total, choco_total)) {
            auto moves = legal_moves_choco(g, coatp(), chocop());
            if (moves.empty()) {
                gen_choco::reshuffle(g, rng, coatp(), chocop());
                moves = legal_moves_choco(g, coatp(), chocop());
                if (moves.empty()) break;
            }
            int prog = 0;
            double best_v = -1e18;
            Move best = moves[0];
            for (const auto& m : moves) {
                Grid gc = g;
                std::mt19937 rc = rng;
                std::vector<std::vector<int>> jc = jelly, cc = coat, hc = choco;
                swap_cells(gc, m.a, m.b);
                gen_choco::ChocoResolveResult rr = gen_choco::resolve(
                    gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                    hc.empty() ? nullptr : &hc, nullptr, true);
                if (move_progresses_choco(rr, lv)) prog++;
                double prog_h = 0.0;
                for (const auto& o : lv.objectives)
                    if (o.type == OBJ_CLEAR_CHOCO) prog_h += rr.choco_cleared;
                double v = h.w_obj * prog_h + h.w_score * (double)rr.score;
                if (v > best_v) { best_v = v; best = m; }
            }
            curve.push_back(prog);
            swap_cells(g, best.a, best.b);
            gen_choco::ChocoResolveResult rr = gen_choco::resolve(
                g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                choco.empty() ? nullptr : &choco, nullptr, true);
            score += rr.score;
            accumulate(collected, rr.by_species);
            jelly_total += rr.jelly_cleared;
            blocker_total += rr.blocker_cleared;
            choco_total += rr.choco_cleared;
            if (!choco.empty() && rr.choco_cleared == 0)
                gen_choco::spread_chocolate(choco, g, rng);
            moves_used++;
        }
        return curve;
    }
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
