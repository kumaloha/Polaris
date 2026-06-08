#pragma once
// solver.hpp — 求解器（09 §3）。求解器既是"玩家"也是"评估器"。
// v1：贪心玩家(地板代言人)。后续加 MCTS(天花板)、Beam、投票评估。
#include "match_engine.hpp"
#include <cstdint>

namespace me {

// ───────────── 巧克力蔓延：直接复用 match_engine.hpp 的 *_choco 原语（H4 去重）─────────────
// 历史上这里有一份自包含的 gen_choco 子命名空间拷贝（早期 match_engine.hpp 尚无巧克力时为避重定义而隔离）。
//   现 match_engine.hpp 已提供完整一套：find_matches_choco / apply_gravity_choco / is_legal_swap_choco /
//   has_legal_move_choco / eat_chocolate / spread_chocolate / count_chocolate / resolve_choco（含 ChocoResolveResult）。
//   隔离理由消失 → 删掉整套拷贝，求解器/生成器统一调 me:: 原语，避免"改一处漏另一处"导致标定端与镜像端分叉。
//   调用处一律用显式 me:: 限定（消除 ADL 二义：旧 gen_choco 内非限定调用曾把 me:: 同名函数拉进重载集）。
// 唯一例外：choco 感知的洗牌 match_engine.hpp 未提供（基础 reshuffle 只 coat 感知）。这里保留一个最小的
//   求解器特有包装 reshuffle_choco，内部只调 me:: 的 find_matches_choco / has_legal_move_choco 原语，不复制规则。

// choco 感知洗牌：仅打乱普通棋子(非墙/空/锁/巧克力)，直到无现成消除且有 choco 感知合法步。
//   match_engine.hpp 无对应原语，故作为求解器特有包装保留；判定全部委托 me:: 的 *_choco 原语。
inline void reshuffle_choco(Grid& g, std::mt19937& rng,
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
        bool no_match = find_matches_choco(g, coat, choco).empty();
        if (no_match && has_legal_move_choco(g, coat, choco)) return;
        if (no_match && !have_safe) { have_safe = true; safe_tiles = tiles; }
    }
    if (have_safe)
        for (size_t i = 0; i < positions.size(); ++i)
            g[positions[i].y][positions[i].x] = safe_tiles[i];
}

enum ObjType { OBJ_SCORE, OBJ_COLLECT, OBJ_CLEAR_JELLY, OBJ_CLEAR_BLOCKER, OBJ_CLEAR_CHOCO, OBJ_COLLECT_INGREDIENT, OBJ_DEFUSE_BOMB,
               OBJ_POP_POPCORN, OBJ_DESTROY_CAKE, OBJ_REVEAL_MYSTERY };

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
    std::vector<std::vector<int>> bomb;         // 炸弹层（倒计时炸弹关，bomb[y][x]=N=该格剩余 N 步倒计时，0=无炸弹，可选）
    std::vector<std::vector<int>> cannon;       // 糖果炮层（cannon[y][x]=1 产普通糖 / 2 产原料，炮口格 grid=WALL，可选）
    std::vector<std::vector<int>> popcorn;      // 爆米花层（popcorn[y][x]=N=该格剩余命中数，不可消不可换随重力落，可选）
    std::vector<std::vector<int>> cake;         // 蛋糕炸弹层（cake[y][x]=N=该蛋糕剩余血量，格 grid=WALL，可选）
    std::vector<std::vector<int>> mystery;      // 神秘糖层（mystery[y][x]=1=神秘糖格，普通棋子可消可换、被消时揭开，可选）
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
                           int ingredient_collected = 0, int bomb_defused = 0,
                           int popcorn_hit = 0, int cake_destroyed = 0, int mystery_revealed = 0) {
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
        } else if (o.type == OBJ_DEFUSE_BOMB) {
            if (bomb_defused < o.target) return false;  // 拆够 N 个炸弹（"全程无爆"铁律由 play_bomb 的 won 另判）
        } else if (o.type == OBJ_POP_POPCORN) {
            if (popcorn_hit < o.target) return false;   // 砸够 N 次爆米花（含归0变彩球那次）
        } else if (o.type == OBJ_DESTROY_CAKE) {
            if (cake_destroyed < o.target) return false; // 炸毁够 N 个蛋糕（血量归0）
        } else if (o.type == OBJ_REVEAL_MYSTERY) {
            if (mystery_revealed < o.target) return false; // 揭开够 N 个神秘糖
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
    int ingredient_collected = 0;  // 累计落到出口被收的原料数（运料关 / 糖果炮产原料关）
    int bomb_defused = 0;        // 累计因消除而拆掉的炸弹数（炸弹关）
    bool bomb_exploded = false;  // 是否有炸弹倒计时归零引爆（炸弹关：任一爆 → 本局判负）
    int popcorn_hit = 0;         // 累计被特效命中递减的爆米花次数（爆米花关）
    int cake_destroyed = 0;      // 累计炸毁(血量归0)的蛋糕数（蛋糕关）
    int mystery_revealed = 0;    // 累计被揭开的神秘糖数（神秘糖关）
    int cannon_spawned = 0;      // 累计从炮口产出的棋子数（糖果炮关，供断言/调试）
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
inline double move_value_choco(const ChocoResolveResult& rr, const Level& lv) {
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
inline bool move_progresses_choco(const ChocoResolveResult& rr, const Level& lv) {
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
            if (x + 1 < w && is_legal_swap_choco(g, {x, y}, {x + 1, y}, coat, choco))
                out.push_back({{x, y}, {x + 1, y}});
            if (y + 1 < h && is_legal_swap_choco(g, {x, y}, {x, y + 1}, coat, choco))
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

// ───────────── 倒计时炸弹关：标定辅助（紧迫度激励让裸 Core 画像玩家会主动拆弹）─────────────
// 命门：炸弹关进度信号天然稀疏（拆弹=消除炸弹格才计 bomb_defused），且裸 Core 玩家无"拆弹"动机——
//   贪心/画像只追分数/目标，会无视炸弹格 → 倒计时一路递减 → 必有炸弹归零引爆 → pass≡0（标不出可解关）。
//   故仿运料下沉势能加"紧迫度势能"：盘上每个存活炸弹按 (CAP - 倒计时) 计势能（倒计时越低势能越高=越该先拆）。
//   候选评估里【减去】结算后的残留紧迫势能 → 消掉炸弹(尤其将爆的低倒计时格)使势能骤降 = 该步价值升高，
//   于是画像玩家被牵引去优先消除快爆的炸弹格。权重远小于"拆一个"(value W=100)：拆净收益恒正，不会卡着不拆。
inline double bomb_urgency_bonus(const std::vector<std::vector<int>>& bomb) {
    if (bomb.empty()) return 0.0;
    const double CAP = 12.0;  // 紧迫度封顶：倒计时 >= CAP 的炸弹视作"还不急"(势能 0)
    double pot = 0.0;
    for (const auto& row : bomb)
        for (int v : row)
            if (v > 0) {
                double ttl = (v < (int)CAP) ? (double)v : CAP;
                pot += (CAP - ttl);  // 倒计时越低 → 势能越高 → 越该先消掉它
            }
    return 2.0 * pot;
}

// 一步交换的"价值"（炸弹关）：OBJ_DEFUSE_BOMB → 本步拆掉的炸弹数×W；其余目标同 move_value 口径。
inline double move_value_bomb(const BombResolveResult& rr, const Level& lv) {
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
        else if (o.type == OBJ_DEFUSE_BOMB) v += W * rr.bomb_defused;
    }
    v += 0.01 * rr.score;
    return v;
}

// 一步是否"推进炸弹目标"（炸弹关 progress 曲线用）。
inline bool move_progresses_bomb(const BombResolveResult& rr, const Level& lv) {
    if (lv.objectives.empty()) return rr.cleared > 0;
    for (const auto& o : lv.objectives) {
        if (o.type == OBJ_SCORE && rr.score > 0) return true;
        if (o.type == OBJ_COLLECT) {
            int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
            if (g > 0) return true;
        }
        if (o.type == OBJ_CLEAR_JELLY && rr.jelly_cleared > 0) return true;
        if (o.type == OBJ_CLEAR_BLOCKER && rr.blocker_cleared > 0) return true;
        if (o.type == OBJ_DEFUSE_BOMB && rr.bomb_defused > 0) return true;
    }
    return false;
}

// ═══════════════ H5：四个"死功能"障碍入库（cannon / popcorn / cake / mystery）═══════════════
// 设计要点：match_engine.hpp 已提供这四层的全部机械原语（spawn_from_cannons / hit_popcorn /
//   blast_cakes / reveal_mystery_at 等），solver 端【只读调用、绝不修改】。各层的"求解器回合骨架"
//   仿 play_bomb/play_ingredient：在副本上试每个候选选最佳步、真实结算、按需推进层目标。
// 特效标定难题（呼应铁律"宁可保守可解、不标真机不可解的关"）：
//   裸 C++ Core 不实现特效(条纹/爆炸/彩球)，而 popcorn(仅特效命中)、cake(引爆链)、cannon(产出后级联)
//   部分依赖特效。处理方案见各层注释——popcorn/cake 用【保守标定】(target 取地板值、move 给宽裕)，
//   cannon(产出直接镜像)/mystery(被消即揭开,普通三消即触发) 标定相对直接。

// ───────────── 蛋糕炸弹关（OBJ_DESTROY_CAKE）：resolve 镜像 GDScript 的 cake 分支 ─────────────
struct CakeResolveResult {
    int score = 0, cascades = 0, cleared = 0;
    int jelly_cleared = 0, blocker_cleared = 0, cake_destroyed = 0;
    std::vector<int> by_species;
};

// cake 感知的 resolve：蛋糕格 grid=WALL（find_matches 自动跳过），每轮消除后用 blast_cakes 处理
//   "正交相邻被清的蛋糕 -1 + 引爆一圈 / 归0大爆炸 5x5 + 移除"，引爆波及的普通格并入清除集再下落级联。
//   裸 Core 无特效链展开（引爆卷入的条纹/爆炸不再连锁）→ 标定偏保守（真机蛋糕威力略大于此），呼应铁律。
inline CakeResolveResult resolve_cake(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                                      std::vector<std::vector<int>>* jelly,
                                      std::vector<std::vector<int>>* coat,
                                      std::vector<std::vector<int>>& cake,
                                      bool do_refill = true) {
    CakeResolveResult r;
    while (true) {
        auto matched = find_matches(g, coat);
        if (matched.empty()) break;
        r.cascades++;
        int H = (int)g.size(), W = (int)g[0].size();
        std::vector<std::vector<char>> ism(H, std::vector<char>(W, 0));
        for (const auto& p : matched) ism[p.y][p.x] = 1;
        if (coat) {  // 破锁：消除内/相邻的锁住格 -1
            for (int y = 0; y < H; ++y)
                for (int x = 0; x < W; ++x) {
                    if ((*coat)[y][x] <= 0) continue;
                    bool hit = ism[y][x]
                        || (x > 0 && ism[y][x - 1]) || (x + 1 < W && ism[y][x + 1])
                        || (y > 0 && ism[y - 1][x]) || (y + 1 < H && ism[y + 1][x]);
                    if (hit) { (*coat)[y][x]--; r.blocker_cleared++; }
                }
        }
        // 收原始匹配的清除集（蛋糕格 grid=WALL 不会在 matched 里）
        std::vector<Vec2> cleared;
        for (const auto& p : matched) {
            int s = g[p.y][p.x];
            if (s >= 0) {
                if ((int)r.by_species.size() <= s) r.by_species.resize(s + 1, 0);
                r.by_species[s]++;
            }
            if (jelly && (*jelly)[p.y][p.x] > 0) { (*jelly)[p.y][p.x]--; r.jelly_cleared++; }
            g[p.y][p.x] = EMPTY;
            cleared.push_back(p);
        }
        r.cleared += (int)matched.size();
        r.score += score_for_clear((int)matched.size(), r.cascades);
        // 蛋糕结算：相邻被清的蛋糕 -1 + 引爆几何（普通格）。blast_out 收引爆要清的普通格并入清除。
        if (!cake.empty()) {
            std::vector<Vec2> blast;
            r.cake_destroyed += blast_cakes(g, cake, cleared, &blast);
            for (const auto& bp : blast) {
                if (g[bp.y][bp.x] == EMPTY || g[bp.y][bp.x] == WALL) continue;  // 已清/墙跳过
                if (coat && (*coat)[bp.y][bp.x] > 0) continue;                  // 锁住格只破层(上面已处理)、不被引爆直清
                int s = g[bp.y][bp.x];
                if (s >= 0) {
                    if ((int)r.by_species.size() <= s) r.by_species.resize(s + 1, 0);
                    r.by_species[s]++;
                }
                if (jelly && (*jelly)[bp.y][bp.x] > 0) { (*jelly)[bp.y][bp.x]--; r.jelly_cleared++; }
                g[bp.y][bp.x] = EMPTY;
                r.cleared += 1;
            }
        }
        apply_gravity(g, coat);
        if (do_refill) refill(g, species, rng, nullptr);
    }
    return r;
}

// ───────────── 神秘糖关（OBJ_REVEAL_MYSTERY）：resolve 镜像 GDScript 的 mystery 分支 ─────────────
struct MysResolveResult {
    int score = 0, cascades = 0, cleared = 0;
    int jelly_cleared = 0, blocker_cleared = 0, mystery_revealed = 0;
    std::vector<int> by_species;
};

// mystery 感知的 resolve：神秘糖格 grid 是普通棋子【正常参与匹配】，但被匹配到时【不清空】而是揭开为
//   随机内容(reveal_mystery_at：70% 普通糖 / 20% 特效→裸 Core 退化普通糖 / 10% 原料)、mystery→0。
//   故标定相对直接（普通三消即触发揭开）。揭开后该格变普通棋子继续参与后续级联。
inline MysResolveResult resolve_mystery(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                                        std::vector<std::vector<int>>* jelly,
                                        std::vector<std::vector<int>>* coat,
                                        std::vector<std::vector<int>>& mystery,
                                        bool do_refill = true) {
    MysResolveResult r;
    while (true) {
        auto matched = find_matches(g, coat);
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
        int cleared_this = 0;
        for (const auto& p : matched) {
            if (!mystery.empty() && mystery[p.y][p.x] > 0) {
                // 神秘糖格被消除 → 揭开为随机内容(mystery→0)、不清空、不计入收集/清除
                reveal_mystery_at(g, nullptr, mystery, p, rng, species);
                r.mystery_revealed += 1;
                continue;
            }
            int s = g[p.y][p.x];
            if (s >= 0) {
                if ((int)r.by_species.size() <= s) r.by_species.resize(s + 1, 0);
                r.by_species[s]++;
            }
            if (jelly && (*jelly)[p.y][p.x] > 0) { (*jelly)[p.y][p.x]--; r.jelly_cleared++; }
            g[p.y][p.x] = EMPTY;
            cleared_this++;
        }
        r.cleared += cleared_this;
        if (cleared_this > 0) r.score += score_for_clear(cleared_this, r.cascades);
        apply_gravity_mystery(g, coat, nullptr, &mystery);  // 神秘糖标记随 grid 同步落
        if (do_refill) refill(g, species, rng, nullptr);
    }
    return r;
}

// ───────────── 价值/进度辅助（cake / mystery / popcorn / cannon 关）─────────────
inline double move_value_cake(const CakeResolveResult& rr, const Level& lv) {
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
        else if (o.type == OBJ_DESTROY_CAKE) v += W * rr.cake_destroyed;
    }
    v += 0.01 * rr.score;
    return v;
}

inline double move_value_mystery(const MysResolveResult& rr, const Level& lv) {
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
        else if (o.type == OBJ_REVEAL_MYSTERY) v += W * rr.mystery_revealed;
    }
    v += 0.01 * rr.score;
    return v;
}

// 一步交换的"价值"（爆米花关）：OBJ_POP_POPCORN → 本步保守溅射命中数×W；其余目标同 move_value 口径。
//   hits 由 play_popcorn 在候选评估时算好传入（裸 Core 无特效，命中=清除集相邻爆米花的几何近似）。
inline double move_value_popcorn(const ResolveResult& rr, int hits, const Level& lv) {
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
        else if (o.type == OBJ_POP_POPCORN) v += W * hits;
    }
    v += 0.01 * rr.score;
    return v;
}

// 蛋糕邻近势能：剩余蛋糕周围一圈的普通棋子数（越多=越易触发相邻消除引爆它）。牵引画像玩家
//   去消除蛋糕近旁的格（蛋糕关进度信号稀疏，不引导则画像只刷分、无视蛋糕→pass≡0）。权重远小于"炸毁一个"。
inline double cake_adjacency_bonus(const Grid& g, const std::vector<std::vector<int>>& cake) {
    if (cake.empty()) return 0.0;
    int H = (int)g.size();
    if (H == 0) return 0.0;
    int W = (int)g[0].size();
    double pot = 0.0;
    const int dx[] = {1, -1, 0, 0}, dy[] = {0, 0, 1, -1};
    for (int y = 0; y < H; ++y)
        for (int x = 0; x < W; ++x) {
            if (cake[y][x] <= 0) continue;
            for (int d = 0; d < 4; ++d) {
                int nx = x + dx[d], ny = y + dy[d];
                if (nx >= 0 && nx < W && ny >= 0 && ny < H && g[ny][nx] >= 0) pot += 1.0;
            }
        }
    return 0.5 * pot;
}

// ───────────── 爆米花关求解辅助（popcorn 感知枚举/死局/洗牌/resolve）─────────────
// 爆米花格(popcorn>0)与原料格同理【不可消不可换】，故枚举/洗牌/匹配用 popcorn 感知版本
//   （直接调 match_engine.hpp 的 *_popcorn 原语，只读不改）。

// popcorn 感知枚举合法交换：爆米花格不可参与交换。
inline std::vector<Move> legal_moves_popcorn(Grid& g,
                                             const std::vector<std::vector<int>>* coat,
                                             const std::vector<std::vector<int>>* choco,
                                             const std::vector<std::vector<int>>* popcorn) {
    std::vector<Move> out;
    int h = (int)g.size();
    if (h == 0) return out;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && is_legal_swap_popcorn(g, {x, y}, {x + 1, y}, coat, choco, nullptr, popcorn))
                out.push_back({{x, y}, {x + 1, y}});
            if (y + 1 < h && is_legal_swap_popcorn(g, {x, y}, {x, y + 1}, coat, choco, nullptr, popcorn))
                out.push_back({{x, y}, {x, y + 1}});
        }
    return out;
}

// popcorn 感知死局判定。
inline bool has_legal_move_popcorn(Grid& g, const std::vector<std::vector<int>>* coat,
                                   const std::vector<std::vector<int>>* choco,
                                   const std::vector<std::vector<int>>* popcorn) {
    int h = (int)g.size();
    if (h == 0) return false;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && is_legal_swap_popcorn(g, {x, y}, {x + 1, y}, coat, choco, nullptr, popcorn)) return true;
            if (y + 1 < h && is_legal_swap_popcorn(g, {x, y}, {x, y + 1}, coat, choco, nullptr, popcorn)) return true;
        }
    return false;
}

// popcorn 感知洗牌：仅打乱普通棋子（非墙/空/锁/巧克力/爆米花），直到无现成消除且有 popcorn 感知合法步。
inline void reshuffle_popcorn(Grid& g, std::mt19937& rng,
                              const std::vector<std::vector<int>>* coat,
                              const std::vector<std::vector<int>>* choco,
                              const std::vector<std::vector<int>>* popcorn) {
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
            if (popcorn && (*popcorn)[y][x] > 0) continue;  // 爆米花格不参与洗牌（不可换）
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
        bool no_match = find_matches_popcorn(g, coat, choco, nullptr, popcorn).empty();
        if (no_match && has_legal_move_popcorn(g, coat, choco, popcorn)) return;
        if (no_match && !have_safe) { have_safe = true; safe_tiles = tiles; }
    }
    if (have_safe)
        for (size_t i = 0; i < positions.size(); ++i)
            g[positions[i].y][positions[i].x] = safe_tiles[i];
}

// popcorn 关结算结果：普通 ResolveResult + 本步保守溅射命中的爆米花次数。
struct PopResolveResult {
    ResolveResult base;
    int popcorn_hit = 0;
};

// popcorn 感知 resolve：爆米花格不参与匹配（find_matches_popcorn 跳过、断串），随重力下落（apply_gravity_popcorn）。
//   命中近似（特效标定难题核心）：裸 Core 无特效，每轮消除把【与本轮清除集正交相邻】的爆米花格当作"特效溅射命中"
//   → hit_popcorn 递减（几何近似，只算几何不落特效；真机条纹/爆炸/彩球命中面更大，故此近似偏保守，呼应铁律）。
//   命中在每级联里结算（镜像真机 resolve 内 _hit_popcorn 按 cleared_set 递减的位置），归0后 popcorn=0 不再计。
inline PopResolveResult resolve_popcorn(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                                        std::vector<std::vector<int>>* jelly,
                                        std::vector<std::vector<int>>* coat,
                                        std::vector<std::vector<int>>* popcorn) {
    PopResolveResult pr;
    ResolveResult& r = pr.base;
    while (true) {
        auto matched = find_matches_popcorn(g, coat, nullptr, nullptr, popcorn);
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
        // 保守溅射命中：本轮清除集(matched)正交相邻还带命中数的爆米花格 -1（几何近似特效溅射）。
        //   须在清空 grid 前按位置算（爆米花格自身不在 matched 里——它不参与匹配）。
        if (popcorn) {
            std::vector<Vec2> splash;
            std::vector<std::vector<char>> seen(H, std::vector<char>(W, 0));
            const int dx[] = {1, -1, 0, 0}, dy[] = {0, 0, 1, -1};
            for (const auto& p : matched)
                for (int d = 0; d < 4; ++d) {
                    int nx = p.x + dx[d], ny = p.y + dy[d];
                    if (nx < 0 || nx >= W || ny < 0 || ny >= H) continue;
                    if (!seen[ny][nx] && (*popcorn)[ny][nx] > 0) { seen[ny][nx] = 1; splash.push_back({nx, ny}); }
                }
            pr.popcorn_hit += hit_popcorn(*popcorn, splash);
        }
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
        apply_gravity_popcorn(g, coat, nullptr, popcorn);  // 爆米花随重力下落（标记跟随）
        refill(g, species, rng, nullptr);
    }
    return pr;
}

// ───────────── 糖果炮关（OBJ_COLLECT_INGREDIENT，cannon=2 产原料）统一玩家循环 ─────────────
// 镜像 board.gd：换子 → resolve_ingredient（消除→原料随重力落→沉出口收集）→ spawn_from_cannons（每有效步
//   炮口下方产原料）→ apply_gravity_ingredient + resolve_ingredient（产出物级联+收集）。胜利=收够 ingredient。
//   cannon 产出直接镜像 spawn_from_cannons（无特效依赖）→ 标定相对直接。复用 ing 枚举/洗牌(炮口格 grid=WALL
//   不入枚举；产出原料格 ing>0 不可换，与运料关同口径)。
template <typename ValueFn>
inline PlayResult play_cannon(const Level& lv, ValueFn value_fn, bool record_curve) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    std::vector<std::vector<int>> coat = lv.coat;
    std::vector<std::vector<int>> choco = lv.choco;
    std::vector<std::vector<int>> ing = lv.ing;
    std::vector<std::vector<int>> cannon = lv.cannon;
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
        // 糖果炮：每有效步从炮口下方产棋子(cannon=2 产原料)，再结算产出物下落+级联+收集（镜像 _spawn_from_cannons_after_move）
        if (!cannon.empty()) {
            int produced = spawn_from_cannons(cannon, g, lv.species, rng, ing.empty() ? nullptr : &ing);
            res.cannon_spawned += produced;
            if (produced > 0) {
                apply_gravity_ingredient(g, coatp(), chocop(), ingp());
                IngResolveResult pr = resolve_ingredient(
                    g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                    choco.empty() ? nullptr : &choco, ing.empty() ? nullptr : &ing, lv.exit_cols, nullptr, true);
                res.score += pr.score;
                accumulate(collected, pr.by_species);
                jelly_total += pr.jelly_cleared;
                blocker_total += pr.blocker_cleared;
                ing_total += pr.ingredient_collected;
            }
        }
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.ingredient_collected = ing_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, ing_total);
    return res;
}

// ───────────── 蛋糕关统一玩家循环（选步策略由 value_fn 注入）─────────────
// 镜像 board.gd：换子 → resolve_cake（消除→相邻蛋糕-1引爆/归0大爆炸）→ 死局洗牌。蛋糕格 grid=WALL
//   不参与枚举/洗牌（基础 legal_moves/reshuffle 见 WALL 即生效）。候选评估加蛋糕邻近势能牵引玩家消蛋糕近旁格。
template <typename ValueFn>
inline PlayResult play_cake(const Level& lv, ValueFn value_fn, bool record_curve) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    std::vector<std::vector<int>> coat = lv.coat;
    std::vector<std::vector<int>> cake = lv.cake;
    int jelly_total = 0, blocker_total = 0, cake_total = 0;
    auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
    while (res.moves_used < lv.move_limit
           && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, 0, 0, cake_total)) {
        auto moves = legal_moves(g, coatp());
        if (moves.empty()) {  // 死局：coat 感知洗牌续玩（蛋糕格 grid=WALL 不感知枚举/洗牌）
            reshuffle(g, rng, coatp());
            moves = legal_moves(g, coatp());
            if (moves.empty()) break;
        }
        if (record_curve) res.solspace_curve.push_back((int)moves.size());
        double best_v = -1e18;
        Move best = moves[0];
        for (const auto& m : moves) {
            Grid gc = g;
            std::mt19937 rc = rng;
            std::vector<std::vector<int>> jc = jelly, cc = coat, kc = cake;
            swap_cells(gc, m.a, m.b);
            CakeResolveResult rr = resolve_cake(
                gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc, kc, true);
            // 炸毁价值 + 结算后残留蛋糕邻近势能（消蛋糕近旁格→势能升→引向触发引爆）
            double v = value_fn(rr, lv) + cake_adjacency_bonus(gc, kc);
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        CakeResolveResult rr = resolve_cake(
            g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat, cake, true);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        cake_total += rr.cake_destroyed;
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.cake_destroyed = cake_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, 0, 0, cake_total);
    return res;
}

// ───────────── 神秘糖关统一玩家循环（选步策略由 value_fn 注入）─────────────
// 镜像 board.gd：换子 → resolve_mystery（消除→被消的神秘糖揭开为随机内容、mystery→0）→ 死局洗牌。
//   神秘糖格 grid 是普通棋子=正常参与匹配/交换 → 用基础 legal_moves/reshuffle（不感知 mystery）。标定相对直接。
template <typename ValueFn>
inline PlayResult play_mystery(const Level& lv, ValueFn value_fn, bool record_curve) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    std::vector<std::vector<int>> coat = lv.coat;
    std::vector<std::vector<int>> mystery = lv.mystery;
    int jelly_total = 0, blocker_total = 0, mystery_total = 0;
    auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
    while (res.moves_used < lv.move_limit
           && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, 0, 0, 0, mystery_total)) {
        auto moves = legal_moves(g, coatp());
        if (moves.empty()) {  // 死局：coat 感知洗牌续玩（神秘糖是普通棋子，不另感知）
            reshuffle(g, rng, coatp());
            moves = legal_moves(g, coatp());
            if (moves.empty()) break;
        }
        if (record_curve) res.solspace_curve.push_back((int)moves.size());
        double best_v = -1e18;
        Move best = moves[0];
        for (const auto& m : moves) {
            Grid gc = g;
            std::mt19937 rc = rng;
            std::vector<std::vector<int>> jc = jelly, cc = coat, mc = mystery;
            swap_cells(gc, m.a, m.b);
            MysResolveResult rr = resolve_mystery(
                gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc, mc, true);
            double v = value_fn(rr, lv);
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        MysResolveResult rr = resolve_mystery(
            g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat, mystery, true);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        mystery_total += rr.mystery_revealed;
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.mystery_revealed = mystery_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, 0, 0, 0, mystery_total);
    return res;
}

// ───────────── 爆米花关（OBJ_POP_POPCORN）统一玩家循环（选步策略由 value_fn 注入）─────────────
// 命门（特效标定难题核心）：爆米花格 grid 是普通棋子占位、popcorn>0【不参与匹配/不可换/随重力落】，
//   真机里【只有特效(条纹/爆炸/彩球)命中或蛋糕引爆波及】才 popcorn-1、归0变彩球。裸 C++ Core 不实现特效，
//   纯三消打不到爆米花 → popcorn_hit 天然≡0。保守近似（文档标注）：把本步【真实清除集的正交相邻】爆米花格
//   当作"特效溅射命中"驱动 hit_popcorn（几何近似，只算几何不落特效；真机特效命中面更大，故此近似偏保守，
//   呼应铁律"宁可保守可解"）。配合 generate_popcorn_for_difficulty 的保守 target/宽裕步数，标出的关真机必可解。
//   枚举/洗牌用 popcorn 感知版本（爆米花格不可换，与真机一致）。
// value_fn 签名 (ResolveResult, int hits, Level)：hits=本步保守溅射命中数（让画像按 w_obj 自行加权命中，
//   与 bomb/ing/choco 的画像选步口径一致——scorer(w_obj=0) 不追命中、rusher 重命中）。
template <typename ValueFn>
inline PlayResult play_popcorn(const Level& lv, ValueFn value_fn, bool record_curve) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    std::vector<std::vector<int>> coat = lv.coat;
    std::vector<std::vector<int>> choco = lv.choco;
    std::vector<std::vector<int>> popcorn = lv.popcorn;
    int jelly_total = 0, blocker_total = 0, popcorn_total = 0;
    auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
    auto chocop = [&]() { return choco.empty() ? nullptr : &choco; };
    auto popp = [&]() { return popcorn.empty() ? nullptr : &popcorn; };
    while (res.moves_used < lv.move_limit
           && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, 0, popcorn_total)) {
        auto moves = legal_moves_popcorn(g, coatp(), chocop(), popp());
        if (moves.empty()) {  // 死局：popcorn 感知洗牌续玩
            reshuffle_popcorn(g, rng, coatp(), chocop(), popp());
            moves = legal_moves_popcorn(g, coatp(), chocop(), popp());
            if (moves.empty()) break;
        }
        if (record_curve) res.solspace_curve.push_back((int)moves.size());
        double best_v = -1e18;
        Move best = moves[0];
        for (const auto& m : moves) {
            Grid gc = g;
            std::mt19937 rc = rng;
            std::vector<std::vector<int>> jc = jelly, cc = coat, pc = popcorn;
            swap_cells(gc, m.a, m.b);
            // popcorn 感知 resolve：爆米花格不参与匹配（find_matches_popcorn 跳过），随重力下落；
            //   命中（保守溅射近似）在 resolve_popcorn 内每级联结算并回传。
            PopResolveResult rr = resolve_popcorn(gc, lv.species, rc,
                                                  jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                                                  pc.empty() ? nullptr : &pc);
            double v = value_fn(rr.base, rr.popcorn_hit, lv);  // 命中加权交给 value_fn（画像按 w_obj 决定追不追命中）
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        PopResolveResult rr = resolve_popcorn(g, lv.species, rng,
                                              jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                                              popcorn.empty() ? nullptr : &popcorn);
        res.score += rr.base.score;
        accumulate(collected, rr.base.by_species);
        jelly_total += rr.base.jelly_cleared;
        blocker_total += rr.base.blocker_cleared;
        popcorn_total += rr.popcorn_hit;
        res.moves_used++;
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.popcorn_hit = popcorn_total;
    res.won = objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, 0, popcorn_total);
    return res;
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
            reshuffle_choco(g, rng, coatp(), chocop());
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
            ChocoResolveResult rr = resolve_choco(
                gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                hc.empty() ? nullptr : &hc, nullptr, true);
            double v = value_fn(rr, lv);
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        ChocoResolveResult rr = resolve_choco(
            g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
            choco.empty() ? nullptr : &choco, nullptr, true);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        choco_total += rr.choco_cleared;
        if (!choco.empty() && rr.choco_cleared == 0)  // 整步零啃食 → 蔓延一格（镜像 _spread_choco_if_untouched）
            spread_chocolate(choco, g, rng);
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

// ───────────── 倒计时炸弹关统一玩家循环（各类玩家共享回合骨架，选步策略由 value_fn 注入）─────────────
// 镜像 board.gd 回合顺序：换子 → resolve_bomb(消除→拆弹 bomb_defused→炸弹随重力落) → tick_bombs(存活 -1，
//   某格归零未消即引爆→本局立即判负) → 死局洗牌续玩。炸弹格是普通棋子(不切段/不阻断匹配/交换)，
//   故枚举/洗牌用基础 legal_moves/reshuffle(仅 coat 感知；bomb 不感知)，与 match_engine 注释一致。
//   value_fn(BombResolveResult, Level) → 该步价值（已含 move_value_bomb 的拆弹权重）；
//   候选循环额外【减去】结算后残留紧迫势能(bomb_urgency_bonus)→ 牵引玩家优先消除快爆的炸弹格。
//   胜利铁律：全程无引爆(!bomb_exploded) 且 拆够目标数(objectives_met 的 OBJ_DEFUSE_BOMB)。
template <typename ValueFn>
inline PlayResult play_bomb(const Level& lv, ValueFn value_fn, bool record_curve) {
    Grid g = lv.init_board;
    std::mt19937 rng(lv.seed);
    PlayResult res;
    std::vector<int> collected;
    std::vector<std::vector<int>> jelly = lv.jelly;
    std::vector<std::vector<int>> coat = lv.coat;
    std::vector<std::vector<int>> bomb = lv.bomb;
    int jelly_total = 0, blocker_total = 0, bomb_total = 0;
    auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
    while (res.moves_used < lv.move_limit
           && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, bomb_total)) {
        auto moves = legal_moves(g, coatp());
        if (moves.empty()) {  // 死局：coat 感知洗牌续玩（炸弹不感知枚举/洗牌）
            reshuffle(g, rng, coatp());
            moves = legal_moves(g, coatp());
            if (moves.empty()) break;
        }
        if (record_curve) res.solspace_curve.push_back((int)moves.size());
        double best_v = -1e18;
        Move best = moves[0];
        for (const auto& m : moves) {
            Grid gc = g;
            std::mt19937 rc = rng;
            std::vector<std::vector<int>> jc = jelly, cc = coat, bc = bomb;
            swap_cells(gc, m.a, m.b);
            BombResolveResult rr = resolve_bomb(
                gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                bc.empty() ? nullptr : &bc, nullptr, true, m.b);
            // 拆弹价值 − 结算后残留紧迫势能（消掉快爆炸弹使势能骤降 → 该步价值高 → 优先拆将爆的）
            double v = value_fn(rr, lv) - bomb_urgency_bonus(bc);
            if (v > best_v) { best_v = v; best = m; }
        }
        swap_cells(g, best.a, best.b);
        BombResolveResult rr = resolve_bomb(
            g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
            bomb.empty() ? nullptr : &bomb, nullptr, true, best.b);
        res.score += rr.score;
        accumulate(collected, rr.by_species);
        jelly_total += rr.jelly_cleared;
        blocker_total += rr.blocker_cleared;
        bomb_total += rr.bomb_defused;
        res.moves_used++;
        // 有效交换消耗一步 → 存活炸弹倒计时 -1；某格归零未消即引爆 → 立即判负（镜像 _tick_bombs_after_move + is_over）
        if (!bomb.empty() && tick_bombs(bomb) > 0) {
            res.bomb_exploded = true;
            break;
        }
    }
    res.collected = collected;
    res.jelly_cleared = jelly_total;
    res.blocker_cleared = blocker_total;
    res.bomb_defused = bomb_total;
    // 胜利：全程无引爆 且 拆够目标数（任一炸弹爆 → 直接判负，核心张力）
    res.won = !res.bomb_exploded
              && objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, bomb_total);
    return res;
}

// 贪心玩家：每步选"立即得分最高"的交换。代表不规划的休闲玩家=地板。
inline PlayResult greedy_play(const Level& lv) {
    if (!lv.bomb.empty())  // 炸弹关：走 bomb 回合骨架，选步仍按立即分数（休闲玩家=地板，不主动拆弹→炸弹多半爆）
        return play_bomb(lv, [](const BombResolveResult& rr, const Level&) {
            return (double)rr.score; }, false);
    if (!lv.cannon.empty())  // 糖果炮关：走 cannon 回合骨架，选步仍按立即分数（休闲玩家=地板）
        return play_cannon(lv, [](const IngResolveResult& rr, const Level&) {
            return (double)rr.score; }, false);
    if (!lv.popcorn.empty())  // 爆米花关：走 popcorn 回合骨架，选步仍按立即分数（休闲玩家=地板）
        return play_popcorn(lv, [](const ResolveResult& rr, int, const Level&) {
            return (double)rr.score; }, false);
    if (!lv.cake.empty())  // 蛋糕关：走 cake 回合骨架，选步仍按立即分数（休闲玩家=地板，不主动炸蛋糕）
        return play_cake(lv, [](const CakeResolveResult& rr, const Level&) {
            return (double)rr.score; }, false);
    if (!lv.mystery.empty())  // 神秘糖关：走 mystery 回合骨架，选步仍按立即分数（休闲玩家=地板）
        return play_mystery(lv, [](const MysResolveResult& rr, const Level&) {
            return (double)rr.score; }, false);
    if (!lv.ing.empty())  // 运料关：走 ing 回合骨架，选步仍按立即分数（休闲玩家=地板，不主动运料）
        return play_ingredient(lv, [](const IngResolveResult& rr, const Level&) {
            return (double)rr.score; }, false);
    if (!lv.choco.empty())  // 巧克力关：走 choco 回合骨架，选步仍按立即分数（休闲玩家）
        return play_choco(lv, [](const ChocoResolveResult& rr, const Level&) {
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
    if (!lv.bomb.empty())  // 炸弹关：bomb 回合骨架 + 目标感知选步（DEFUSE_BOMB 追拆弹 + 紧迫度优先拆将爆的）
        return play_bomb(lv, move_value_bomb, true);
    if (!lv.cannon.empty())  // 糖果炮关：cannon 回合骨架（每步产原料）+ 目标感知选步（COLLECT_INGREDIENT 追运下产出原料）
        return play_cannon(lv, move_value_ingredient, true);
    if (!lv.popcorn.empty())  // 爆米花关：popcorn 回合骨架 + 目标感知选步（POP_POPCORN 追溅射命中）
        return play_popcorn(lv, move_value_popcorn, true);
    if (!lv.cake.empty())  // 蛋糕关：cake 回合骨架 + 目标感知选步（DESTROY_CAKE 追炸毁 + 邻近势能引向蛋糕）
        return play_cake(lv, move_value_cake, true);
    if (!lv.mystery.empty())  // 神秘糖关：mystery 回合骨架 + 目标感知选步（REVEAL_MYSTERY 追揭开）
        return play_mystery(lv, move_value_mystery, true);
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
    // 四个 H5 层（cannon/popcorn/cake/mystery）：地板用各自 play_* 回合骨架 + 常值选步（不追层目标、取首个合法步），
    //   作为"无脑休闲玩家=地板"。这些层进度信号稀疏，地板不主动推进 → 与目标感知天花板拉开 LFHC 差距。
    //   cannon 必须在 ing 之前判（cannon 关的产出原料会让 lv.ing 非空，但 lv.cannon 才是判别依据）。
    if (!lv.cannon.empty())
        return play_cannon(lv, [](const IngResolveResult& rr, const Level&) { return (double)rr.score; }, false);
    if (!lv.popcorn.empty())
        return play_popcorn(lv, [](const ResolveResult& rr, int, const Level&) { return (double)rr.score; }, false);
    if (!lv.cake.empty())
        return play_cake(lv, [](const CakeResolveResult& rr, const Level&) { return (double)rr.score; }, false);
    if (!lv.mystery.empty())
        return play_mystery(lv, [](const MysResolveResult& rr, const Level&) { return (double)rr.score; }, false);
    if (!lv.bomb.empty()) {  // 炸弹关：随机选步 + bomb 回合（地板下沿，不主动拆弹→炸弹基本全爆）
        Grid g = lv.init_board;
        std::mt19937 rng(lv.seed);
        PlayResult res;
        std::vector<int> collected;
        std::vector<std::vector<int>> jelly = lv.jelly, coat = lv.coat, bomb = lv.bomb;
        int jelly_total = 0, blocker_total = 0, bomb_total = 0;
        auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
        while (res.moves_used < lv.move_limit
               && !objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, bomb_total)) {
            auto moves = legal_moves(g, coatp());
            if (moves.empty()) {
                reshuffle(g, rng, coatp());
                moves = legal_moves(g, coatp());
                if (moves.empty()) break;
            }
            Move m = moves[rng() % moves.size()];
            swap_cells(g, m.a, m.b);
            BombResolveResult rr = resolve_bomb(
                g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                bomb.empty() ? nullptr : &bomb, nullptr, true, m.b);
            res.score += rr.score;
            accumulate(collected, rr.by_species);
            jelly_total += rr.jelly_cleared;
            blocker_total += rr.blocker_cleared;
            bomb_total += rr.bomb_defused;
            res.moves_used++;
            if (!bomb.empty() && tick_bombs(bomb) > 0) { res.bomb_exploded = true; break; }
        }
        res.collected = collected;
        res.jelly_cleared = jelly_total;
        res.blocker_cleared = blocker_total;
        res.bomb_defused = bomb_total;
        res.won = !res.bomb_exploded
                  && objectives_met(lv, res.score, collected, jelly_total, blocker_total, 0, 0, bomb_total);
        return res;
    }
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
                reshuffle_choco(g, rng, coatp(), chocop());
                moves = legal_moves_choco(g, coatp(), chocop());
                if (moves.empty()) break;
            }
            Move m = moves[rng() % moves.size()];
            swap_cells(g, m.a, m.b);
            ChocoResolveResult rr = resolve_choco(
                g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                choco.empty() ? nullptr : &choco, nullptr, true);
            res.score += rr.score;
            accumulate(collected, rr.by_species);
            jelly_total += rr.jelly_cleared;
            blocker_total += rr.blocker_cleared;
            choco_total += rr.choco_cleared;
            if (!choco.empty() && rr.choco_cleared == 0)  // 整步零啃食 → 蔓延一格
                spread_chocolate(choco, g, rng);
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
    if (!lv.bomb.empty())  // 炸弹关：bomb 回合骨架 + 画像选步（目标进度含 bomb_defused；紧迫度牵引由 play_bomb 统一注入）
        return play_bomb(lv, [&h](const BombResolveResult& rr, const Level& l) {
            double prog = 0.0;
            for (const auto& o : l.objectives) {
                if (o.type == OBJ_SCORE) prog += rr.score / 100.0;
                else if (o.type == OBJ_COLLECT) {
                    int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
                    prog += g;
                } else if (o.type == OBJ_CLEAR_JELLY) prog += rr.jelly_cleared;
                else if (o.type == OBJ_CLEAR_BLOCKER) prog += rr.blocker_cleared;
                else if (o.type == OBJ_DEFUSE_BOMB) prog += rr.bomb_defused;
            }
            return h.w_obj * prog + h.w_score * (double)rr.score + h.w_cascade * (double)rr.cascades;
        }, true);
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
        return play_choco(lv, [&h](const ChocoResolveResult& rr, const Level& l) {
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
    if (!lv.cannon.empty())  // 糖果炮关：cannon 回合骨架 + 画像选步（目标进度含 ingredient_collected = 运下产出原料）
        return play_cannon(lv, [&h](const IngResolveResult& rr, const Level& l) {
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
    if (!lv.popcorn.empty())  // 爆米花关：popcorn 回合骨架 + 画像选步（目标进度含 hits=保守溅射命中）
        return play_popcorn(lv, [&h](const ResolveResult& rr, int hits, const Level& l) {
            double prog = 0.0;
            for (const auto& o : l.objectives) {
                if (o.type == OBJ_SCORE) prog += rr.score / 100.0;
                else if (o.type == OBJ_COLLECT) {
                    int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
                    prog += g;
                } else if (o.type == OBJ_CLEAR_JELLY) prog += rr.jelly_cleared;
                else if (o.type == OBJ_CLEAR_BLOCKER) prog += rr.blocker_cleared;
                else if (o.type == OBJ_POP_POPCORN) prog += hits;
            }
            return h.w_obj * prog + h.w_score * (double)rr.score + h.w_cascade * (double)rr.cascades;
        }, true);
    if (!lv.cake.empty())  // 蛋糕关：cake 回合骨架 + 画像选步（目标进度含 cake_destroyed；邻近势能引向由 play_cake 注入）
        return play_cake(lv, [&h](const CakeResolveResult& rr, const Level& l) {
            double prog = 0.0;
            for (const auto& o : l.objectives) {
                if (o.type == OBJ_SCORE) prog += rr.score / 100.0;
                else if (o.type == OBJ_COLLECT) {
                    int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
                    prog += g;
                } else if (o.type == OBJ_CLEAR_JELLY) prog += rr.jelly_cleared;
                else if (o.type == OBJ_CLEAR_BLOCKER) prog += rr.blocker_cleared;
                else if (o.type == OBJ_DESTROY_CAKE) prog += rr.cake_destroyed;
            }
            return h.w_obj * prog + h.w_score * (double)rr.score + h.w_cascade * (double)rr.cascades;
        }, true);
    if (!lv.mystery.empty())  // 神秘糖关：mystery 回合骨架 + 画像选步（目标进度含 mystery_revealed）
        return play_mystery(lv, [&h](const MysResolveResult& rr, const Level& l) {
            double prog = 0.0;
            for (const auto& o : l.objectives) {
                if (o.type == OBJ_SCORE) prog += rr.score / 100.0;
                else if (o.type == OBJ_COLLECT) {
                    int g = (o.species >= 0 && o.species < (int)rr.by_species.size()) ? rr.by_species[o.species] : 0;
                    prog += g;
                } else if (o.type == OBJ_CLEAR_JELLY) prog += rr.jelly_cleared;
                else if (o.type == OBJ_CLEAR_BLOCKER) prog += rr.blocker_cleared;
                else if (o.type == OBJ_REVEAL_MYSTERY) prog += rr.mystery_revealed;
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
    // H5 四层（cannon/popcorn/cake/mystery）：节奏曲线复用各自目标感知玩家的"每步可选有效交换数"曲线
    //   （solspace_curve，随障碍/产出推进自然前松后紧）。rhythm 是软质量项(只需 >=0、确定性)，故此近似足够，
    //   且避免在此再展开四套回合循环。cannon 必须先判（其 ing 层非空，否则误入下方运料分支）。
    if (!lv.cannon.empty()) return play_cannon(lv, move_value_ingredient, true).solspace_curve;
    if (!lv.popcorn.empty()) return play_popcorn(lv, move_value_popcorn, true).solspace_curve;
    if (!lv.cake.empty()) return play_cake(lv, move_value_cake, true).solspace_curve;
    if (!lv.mystery.empty()) return play_mystery(lv, move_value_mystery, true).solspace_curve;
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
                reshuffle_choco(g, rng, coatp(), chocop());
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
                ChocoResolveResult rr = resolve_choco(
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
            ChocoResolveResult rr = resolve_choco(
                g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                choco.empty() ? nullptr : &choco, nullptr, true);
            score += rr.score;
            accumulate(collected, rr.by_species);
            jelly_total += rr.jelly_cleared;
            blocker_total += rr.blocker_cleared;
            choco_total += rr.choco_cleared;
            if (!choco.empty() && rr.choco_cleared == 0)
                spread_chocolate(choco, g, rng);
            moves_used++;
        }
        return curve;
    }
    if (!lv.bomb.empty()) {  // 炸弹关：rusher 选步(紧迫度牵引)，记录每步"能推进拆弹目标的交换数"
        Grid g = lv.init_board;
        std::mt19937 rng(lv.seed);
        std::vector<int> collected;
        std::vector<std::vector<int>> jelly = lv.jelly, coat = lv.coat, bomb = lv.bomb;
        int jelly_total = 0, blocker_total = 0, bomb_total = 0, score = 0, moves_used = 0;
        std::vector<int> curve;
        auto coatp = [&]() { return coat.empty() ? nullptr : &coat; };
        while (moves_used < lv.move_limit
               && !objectives_met(lv, score, collected, jelly_total, blocker_total, 0, 0, bomb_total)) {
            auto moves = legal_moves(g, coatp());
            if (moves.empty()) {
                reshuffle(g, rng, coatp());
                moves = legal_moves(g, coatp());
                if (moves.empty()) break;
            }
            int prog = 0;
            double best_v = -1e18;
            Move best = moves[0];
            for (const auto& m : moves) {
                Grid gc = g;
                std::mt19937 rc = rng;
                std::vector<std::vector<int>> jc = jelly, cc = coat, bc = bomb;
                swap_cells(gc, m.a, m.b);
                BombResolveResult rr = resolve_bomb(
                    gc, lv.species, rc, jc.empty() ? nullptr : &jc, cc.empty() ? nullptr : &cc,
                    bc.empty() ? nullptr : &bc, nullptr, true, m.b);
                if (move_progresses_bomb(rr, lv)) prog++;
                double prog_h = 0.0;
                for (const auto& o : lv.objectives)
                    if (o.type == OBJ_DEFUSE_BOMB) prog_h += rr.bomb_defused;
                double v = h.w_obj * prog_h + h.w_score * (double)rr.score - bomb_urgency_bonus(bc);
                if (v > best_v) { best_v = v; best = m; }
            }
            curve.push_back(prog);
            swap_cells(g, best.a, best.b);
            BombResolveResult rr = resolve_bomb(
                g, lv.species, rng, jelly.empty() ? nullptr : &jelly, coat.empty() ? nullptr : &coat,
                bomb.empty() ? nullptr : &bomb, nullptr, true, best.b);
            score += rr.score;
            accumulate(collected, rr.by_species);
            jelly_total += rr.jelly_cleared;
            blocker_total += rr.blocker_cleared;
            bomb_total += rr.bomb_defused;
            moves_used++;
            if (!bomb.empty() && tick_bombs(bomb) > 0) break;  // 引爆 → 局终
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
