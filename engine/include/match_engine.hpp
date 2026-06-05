#pragma once
// match_engine.hpp — 消除 Core 规则的 C++ 镜像（与 godot/core/match_engine.gd 一一对应）。
// 这是 09 护城河的地基：求解器/生成器都基于这套规则。grid[y][x]，坐标 Vec2{x,y}。
#include <vector>
#include <random>
#include <deque>
#include <cstdlib>
#include <algorithm>

namespace me {

constexpr int EMPTY = -1;
constexpr int WALL = -2;  // 战场切割/异形棋盘：不可消、不可动、不补充；分隔区域
// 注：C++ 裸 Core 不实现特效（4/5/T-L 仅 Godot 端）。原先残留的 Special enum 已删，避免误导性接口。

struct Vec2 {
    int x = 0, y = 0;
    bool operator==(const Vec2& o) const { return x == o.x && y == o.y; }
};

using Grid = std::vector<std::vector<int>>;

// 找出所有应被消除的格子（横/竖 >=3 同 species），去重。
inline std::vector<Vec2> find_matches(const Grid& g,
                                      const std::vector<std::vector<int>>* coat = nullptr) {
    int h = (int)g.size();
    if (h == 0) return {};
    int w = (int)g[0].size();
    std::vector<std::vector<char>> mark(h, std::vector<char>(w, 0));
    // 横向串（跳过 EMPTY 和 WALL：它们不参与消除、也不能让墙连成串）
    for (int y = 0; y < h; ++y) {
        int x = 0;
        while (x < w) {
            if (g[y][x] == EMPTY || g[y][x] == WALL || (coat && (*coat)[y][x] > 0)) { ++x; continue; }  // 锁住格不可匹配
            int e = x;
            while (e + 1 < w && g[y][e + 1] == g[y][x] && !(coat && (*coat)[y][e + 1] > 0)) ++e;
            if (e - x + 1 >= 3)
                for (int k = x; k <= e; ++k) mark[y][k] = 1;
            x = e + 1;
        }
    }
    // 纵向串
    for (int x = 0; x < w; ++x) {
        int y = 0;
        while (y < h) {
            if (g[y][x] == EMPTY || g[y][x] == WALL || (coat && (*coat)[y][x] > 0)) { ++y; continue; }  // 锁住格不可匹配
            int e = y;
            while (e + 1 < h && g[e + 1][x] == g[y][x] && !(coat && (*coat)[e + 1][x] > 0)) ++e;
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

// 重力：每列非空落到列底，空升到顶。墙(WALL)不动，把列切成若干独立段，各段内分别下落。
inline void apply_gravity(Grid& g, const std::vector<std::vector<int>>* coat = nullptr) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    for (int x = 0; x < w; ++x) {
        int seg_start = 0;
        for (int y = 0; y <= h; ++y) {
            // 墙 与 锁住格(coat>0) 都不可动：作为段边界，原地保留
            if (y == h || g[y][x] == WALL || (coat && (*coat)[y][x] > 0)) {
                std::vector<int> stack;  // 段内非空棋子（段内无墙）
                for (int k = seg_start; k < y; ++k)
                    if (g[k][x] != EMPTY) stack.push_back(g[k][x]);
                int seg_len = y - seg_start;
                int empties = seg_len - (int)stack.size();
                for (int k = seg_start; k < y; ++k) {
                    int idx = k - seg_start;
                    g[k][x] = (idx < empties) ? EMPTY : stack[idx - empties];
                }
                seg_start = y + 1;  // 跳过墙
            }
        }
    }
}

// 随机补充：EMPTY 填成 species 里的随机色（注入的 rng → 可复现）。
// 滚动关(feed!=nullptr)：补充【只】按列从预设 feed 队列前端出(长盘内容下流)；feed[x] 空=该列挖穿→留空，不补随机(上面不掉落新棋子)。
// 行序自上而下 → 同一列上方先补 = feed 前端先入；feed=nullptr 时与旧版逐格 rng 消耗完全一致。
inline void refill(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                   std::vector<std::deque<int>>* feed = nullptr) {
    std::uniform_int_distribution<int> dist(0, (int)species.size() - 1);
    int h = (int)g.size();
    int w = h ? (int)g[0].size() : 0;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x)
            if (g[y][x] == EMPTY) {
                if (feed) {  // 滚动关：只从预设 feed 出
                    if (x < (int)feed->size() && !(*feed)[x].empty()) {
                        g[y][x] = (*feed)[x].front();
                        (*feed)[x].pop_front();
                    }
                    // feed[x] 空 = 该列已挖穿 → 顶部不生新棋子，留空(EMPTY)
                } else {
                    g[y][x] = species[dist(rng)];  // 普通关：随机补充
                }
            }
}

// 一次消除得分 = 格数 × 基础分(10) × 连锁档。
inline int score_for_clear(int count, int cascade_level) {
    return count * 10 * cascade_level;
}

struct ResolveResult {
    int score = 0, cascades = 0, cleared = 0;
    int jelly_cleared = 0;        // 本次消除清掉的果冻层数（底层目标）
    int blocker_cleared = 0;      // 本次消除破掉的涂层(冰/锁)层数
    std::vector<int> by_species;  // by_species[s] = 本次消除中 species s 的格数（按需增长）
    bool operator==(const ResolveResult& o) const {
        return score == o.score && cascades == o.cascades && cleared == o.cleared
               && jelly_cleared == o.jelly_cleared && blocker_cleared == o.blocker_cleared
               && by_species == o.by_species;
    }
};

inline void swap_cells(Grid& g, Vec2 a, Vec2 b) {
    std::swap(g[a.y][a.x], g[b.y][b.x]);
}

// 交换是否合法：相邻 + 交换后能形成消除（v1 无特效）。不改变 g（内部换回）。
inline bool is_legal_swap(Grid& g, Vec2 a, Vec2 b,
                          const std::vector<std::vector<int>>* coat = nullptr) {
    if (std::abs(a.x - b.x) + std::abs(a.y - b.y) != 1) return false;
    // 墙/空格不可参与交换（墙不可动）
    int va = g[a.y][a.x], vb = g[b.y][b.x];
    if (va == WALL || vb == WALL || va == EMPTY || vb == EMPTY) return false;
    if (coat && ((*coat)[a.y][a.x] > 0 || (*coat)[b.y][b.x] > 0)) return false;  // 冻住的格不可换
    swap_cells(g, a, b);
    bool found = !find_matches(g, coat).empty();
    swap_cells(g, a, b);
    return found;
}

// 是否存在任一合法交换。
inline bool has_legal_move(Grid& g, const std::vector<std::vector<int>>* coat = nullptr) {
    int h = (int)g.size();
    if (h == 0) return false;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && is_legal_swap(g, {x, y}, {x + 1, y}, coat)) return true;
            if (y + 1 < h && is_legal_swap(g, {x, y}, {x, y + 1}, coat)) return true;
        }
    return false;
}

// 消除→计分→下落→补充，循环直到稳定。原地修改 g。
inline ResolveResult resolve(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                             std::vector<std::vector<int>>* jelly = nullptr,
                             std::vector<std::vector<int>>* coat = nullptr,
                             std::vector<std::deque<int>>* feed = nullptr,
                             bool do_refill = true) {  // 滚动关消除时 do_refill=false=只挖空(补充改由"拉新页"批量做)
    ResolveResult r;
    while (true) {
        auto matched = find_matches(g, coat);
        if (matched.empty()) break;
        r.cascades++;
        if (coat) {  // 涂层(冰/锁)受损：在消除内 或 与消除正交相邻 的涂层格 -1 层
            int H = (int)g.size(), W = (int)g[0].size();
            std::vector<std::vector<char>> ism(H, std::vector<char>(W, 0));
            for (auto& p : matched) ism[p.y][p.x] = 1;
            for (int y = 0; y < H; ++y)
                for (int x = 0; x < W; ++x) {
                    if ((*coat)[y][x] <= 0) continue;
                    bool hit = ism[y][x]
                        || (x > 0 && ism[y][x - 1]) || (x + 1 < W && ism[y][x + 1])
                        || (y > 0 && ism[y - 1][x]) || (y + 1 < H && ism[y + 1][x]);
                    if (hit) { (*coat)[y][x]--; r.blocker_cleared++; }
                }
        }
        for (auto& p : matched) {
            int s = g[p.y][p.x];
            if (s >= 0) {
                if ((int)r.by_species.size() <= s) r.by_species.resize(s + 1, 0);
                r.by_species[s]++;
            }
            if (jelly && (*jelly)[p.y][p.x] > 0) {  // 消除覆盖到的格 → 果冻清一层
                (*jelly)[p.y][p.x]--;
                r.jelly_cleared++;
            }
            g[p.y][p.x] = EMPTY;
        }
        r.cleared += (int)matched.size();
        r.score += score_for_clear((int)matched.size(), r.cascades);
        apply_gravity(g, coat);
        if (do_refill) refill(g, species, rng, feed);
    }
    return r;
}

// 构造初始盘：避免开局现成消除，且保证有合法移动。
// wall_mask（可选）：mask[y][x]!=0 的格放 WALL（异形棋盘），其余填棋子。
inline Grid make_board(int w, int h, const std::vector<int>& species, std::mt19937& rng,
                       const std::vector<std::vector<char>>& wall_mask = {}) {
    bool has_mask = !wall_mask.empty();
    Grid g;
    for (int attempt = 0; attempt < 50; ++attempt) {
        g.assign(h, std::vector<int>(w, EMPTY));
        for (int y = 0; y < h; ++y)
            for (int x = 0; x < w; ++x) {
                if (has_mask && wall_mask[y][x]) { g[y][x] = WALL; continue; }
                std::vector<int> choices = species;
                if (x >= 2 && g[y][x - 1] == g[y][x - 2])
                    choices.erase(std::remove(choices.begin(), choices.end(), g[y][x - 1]), choices.end());
                if (y >= 2 && g[y - 1][x] == g[y - 2][x])
                    choices.erase(std::remove(choices.begin(), choices.end(), g[y - 2][x]), choices.end());
                if (choices.empty()) choices = species;
                std::uniform_int_distribution<int> d(0, (int)choices.size() - 1);
                g[y][x] = choices[d(rng)];
            }
        if (has_legal_move(g)) return g;
    }
    return g;  // 兜底
}

// 死局/需要时洗牌：只重排可动棋子（多重集不变），墙(WALL)/空格(EMPTY)固定不动。
// 验收用 coat 感知的 has_legal_move——忽略冰锁会"看似有步、真实玩家无步"。
// 镜像 godot/core/match_engine.gd 的 reshuffle（RNG 各端独立，不要求跨语言同序列）。
inline void reshuffle(Grid& g, std::mt19937& rng,
                      const std::vector<std::vector<int>>* coat = nullptr) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    std::vector<Vec2> positions;
    std::vector<int> tiles;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            int v = g[y][x];
            if (v == WALL || v == EMPTY) continue;  // 墙/空格不参与洗牌
            positions.push_back({x, y});
            tiles.push_back(v);
        }
    bool have_safe = false;       // 见过的"至少无现成消除"排列（兜底用，避免开局即级联）
    std::vector<int> safe_tiles;
    for (int attempt = 0; attempt < 100; ++attempt) {
        // Fisher-Yates（注入 rng → 可复现）
        for (int i = (int)tiles.size() - 1; i > 0; --i) {
            std::uniform_int_distribution<int> d(0, i);
            std::swap(tiles[(size_t)i], tiles[(size_t)d(rng)]);
        }
        for (size_t i = 0; i < positions.size(); ++i)
            g[positions[i].y][positions[i].x] = tiles[i];
        bool no_match = find_matches(g, coat).empty();
        if (no_match && has_legal_move(g, coat)) return;          // 理想：无消除 + 有合法步
        if (no_match && !have_safe) { have_safe = true; safe_tiles = tiles; }
    }
    // 没凑出理想排列：退而求其次用"至少无现成消除"的（可能无合法步=真死局，罕见）
    if (have_safe) {
        for (size_t i = 0; i < positions.size(); ++i)
            g[positions[i].y][positions[i].x] = safe_tiles[i];
    }
    // 否则保留最后一次（极端病态，几乎不可达）
}

// ───────────── 巧克力蔓延（Chocolate）：对局压力源（C++ 镜像，仅新增函数，不改现有签名）─────────────
// 巧克力语义（与 godot/core/match_engine.gd 一一对应）：
//   占格、不参与 match、不可交换、不下落（gravity 固定切段）、相邻消除则啃掉一格(choco-1)。
//   玩家整步若零啃食 → 从现存巧克力格向随机正交相邻"可侵占格"增殖一格。
// 说明：现有 find_matches/apply_gravity/is_legal_swap 已用 coat>0 表达"不可消/不可动/不可换"，
//   巧克力把同一套"障碍"判定再叠一层 choco>0。为不动现有签名，这里提供独立的 *_choco 版本。

// choco 感知的匹配：巧克力格(choco>0)与锁住格(coat>0)同样不参与匹配、不让串连过去。
inline std::vector<Vec2> find_matches_choco(const Grid& g,
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

// choco 感知的重力：巧克力格(choco>0)与墙/锁住格一样原地固定、把列切段。
inline void apply_gravity_choco(Grid& g, const std::vector<std::vector<int>>* coat,
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

// choco 感知的合法交换：巧克力格(choco>0)与锁住格一样不可参与交换。
inline bool is_legal_swap_choco(Grid& g, Vec2 a, Vec2 b,
                                const std::vector<std::vector<int>>* coat,
                                const std::vector<std::vector<int>>* choco) {
    if (std::abs(a.x - b.x) + std::abs(a.y - b.y) != 1) return false;
    int va = g[a.y][a.x], vb = g[b.y][b.x];
    if (va == WALL || vb == WALL || va == EMPTY || vb == EMPTY) return false;
    if (coat && ((*coat)[a.y][a.x] > 0 || (*coat)[b.y][b.x] > 0)) return false;
    if (choco && ((*choco)[a.y][a.x] > 0 || (*choco)[b.y][b.x] > 0)) return false;  // 巧克力格不可换
    swap_cells(g, a, b);
    bool found = !find_matches_choco(g, coat, choco).empty();
    swap_cells(g, a, b);
    return found;
}

// choco 感知的死局判定。
inline bool has_legal_move_choco(Grid& g, const std::vector<std::vector<int>>* coat,
                                 const std::vector<std::vector<int>>* choco) {
    int h = (int)g.size();
    if (h == 0) return false;
    int w = (int)g[0].size();
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (x + 1 < w && is_legal_swap_choco(g, {x, y}, {x + 1, y}, coat, choco)) return true;
            if (y + 1 < h && is_legal_swap_choco(g, {x, y}, {x, y + 1}, coat, choco)) return true;
        }
    return false;
}

// 啃食：被清除格(cleared)内或正交相邻的巧克力格 -1（巧克力本身不被清）。原地改 choco，返回啃掉数。
inline int eat_chocolate(std::vector<std::vector<int>>& choco,
                         const std::vector<Vec2>& cleared) {
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

// 蔓延：从所有现存巧克力格中，找其随机正交相邻的"可侵占格"
//   （grid 普通棋子 species>=0、非墙非空，且 choco==0），随机选一个变成巧克力。
//   用注入的 rng → 确定性可复现。无处可蔓延返回 false；蔓延一格返回 true。原地改 choco。
//   候选收集顺序固定(行序→列序→四向右左下上)，与 GDScript 端 DIRS 顺序一致 → 同序枚举。
inline bool spread_chocolate(std::vector<std::vector<int>>& choco, const Grid& g,
                             std::mt19937& rng) {
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
                if (choco[ny][nx] > 0) continue;     // 已是巧克力
                if (g[ny][nx] < 0) continue;          // EMPTY(-1)/WALL(-2) 不可侵占
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
    bool operator==(const ChocoResolveResult& o) const {
        return score == o.score && cascades == o.cascades && cleared == o.cleared
               && jelly_cleared == o.jelly_cleared && blocker_cleared == o.blocker_cleared
               && choco_cleared == o.choco_cleared && by_species == o.by_species;
    }
};

// choco 感知的 resolve：消除→破锁/啃巧克力→计分→下落(障碍固定)→补充，循环至稳定。原地改 g/coat/choco。
// 返回含 choco_cleared = 本次结算啃掉的巧克力格数。镜像 _resolve_plain 的 choco 分支。
inline ChocoResolveResult resolve_choco(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                                        std::vector<std::vector<int>>* jelly = nullptr,
                                        std::vector<std::vector<int>>* coat = nullptr,
                                        std::vector<std::vector<int>>* choco = nullptr,
                                        std::vector<std::deque<int>>* feed = nullptr,
                                        bool do_refill = true) {
    ChocoResolveResult r;
    while (true) {
        auto matched = find_matches_choco(g, coat, choco);
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
        if (choco) r.choco_cleared += eat_chocolate(*choco, matched);  // 啃巧克力
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
        apply_gravity_choco(g, coat, choco);
        if (do_refill) refill(g, species, rng, feed);
    }
    return r;
}

// ───────────── 运原料（Ingredients）：C++ 镜像（仅新增函数，不改现有签名）─────────────
// 原料语义（与 godot/core/match_engine.gd 一一对应）：
//   占格、不参与 match、不可交换、【随重力下落】（与 choco 最大不同：choco 固定切段，原料是可动元素）、
//   落到底部出口列(物理最底行 y=h-1 的 exit_cols)即被收集移除(grid→EMPTY, ing→0, ingredient_collected++)。
// 障碍判定沿用 coat>0/choco>0 表达"不可消/不可换"，原料再叠一层 ing>0；为不动现有签名，提供独立 *_ingredient 版本。

// ing 感知的匹配：原料格(ing>0)与锁住/巧克力格一样不参与匹配、断开同色串。
inline std::vector<Vec2> find_matches_ingredient(const Grid& g,
                                                 const std::vector<std::vector<int>>* coat,
                                                 const std::vector<std::vector<int>>* choco,
                                                 const std::vector<std::vector<int>>* ing) {
    int h = (int)g.size();
    if (h == 0) return {};
    int w = (int)g[0].size();
    auto blocked = [&](int x, int y) -> bool {
        return g[y][x] == EMPTY || g[y][x] == WALL
            || (coat && (*coat)[y][x] > 0) || (choco && (*choco)[y][x] > 0)
            || (ing && (*ing)[y][x] > 0);
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

// ing 感知的重力：原料格(ing>0)【随重力下落】——作为段内可动元素和 grid 一起搬运，ing 层与 grid 同步重排。
//   这是与 apply_gravity_choco 的本质区别（巧克力固定切段；原料只随 wall/coat/choco 切段，自身不切段）。
inline void apply_gravity_ingredient(Grid& g, const std::vector<std::vector<int>>* coat,
                                     const std::vector<std::vector<int>>* choco,
                                     std::vector<std::vector<int>>* ing) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    for (int x = 0; x < w; ++x) {
        int seg_start = 0;
        for (int y = 0; y <= h; ++y) {
            // 仅墙/锁住格(coat>0)/巧克力格(choco>0)切段固定；原料不切段（它是段内可动元素）。
            bool fixed = (y < h) && ((coat && (*coat)[y][x] > 0) || (choco && (*choco)[y][x] > 0));
            if (y == h || g[y][x] == WALL || fixed) {
                std::vector<int> stack;       // 段内非空 species
                std::vector<int> ing_stack;   // 段内每个可动格的原料标记，随 stack 同序搬运
                for (int k = seg_start; k < y; ++k)
                    if (g[k][x] != EMPTY) {
                        stack.push_back(g[k][x]);
                        if (ing) ing_stack.push_back((*ing)[k][x]);
                    }
                int seg_len = y - seg_start;
                int empties = seg_len - (int)stack.size();
                for (int k = seg_start; k < y; ++k) {
                    int idx = k - seg_start;
                    if (idx < empties) {
                        g[k][x] = EMPTY;
                        if (ing) (*ing)[k][x] = 0;          // 空格无原料
                    } else {
                        g[k][x] = stack[idx - empties];
                        if (ing) (*ing)[k][x] = ing_stack[idx - empties];  // 原料标记随该格内容一起落
                    }
                }
                seg_start = y + 1;
            }
        }
    }
}

// ing 感知的合法交换：原料格(ing>0)与锁住/巧克力格一样不可参与交换。
inline bool is_legal_swap_ingredient(Grid& g, Vec2 a, Vec2 b,
                                     const std::vector<std::vector<int>>* coat,
                                     const std::vector<std::vector<int>>* choco,
                                     const std::vector<std::vector<int>>* ing) {
    if (std::abs(a.x - b.x) + std::abs(a.y - b.y) != 1) return false;
    int va = g[a.y][a.x], vb = g[b.y][b.x];
    if (va == WALL || vb == WALL || va == EMPTY || vb == EMPTY) return false;
    if (coat && ((*coat)[a.y][a.x] > 0 || (*coat)[b.y][b.x] > 0)) return false;
    if (choco && ((*choco)[a.y][a.x] > 0 || (*choco)[b.y][b.x] > 0)) return false;
    if (ing && ((*ing)[a.y][a.x] > 0 || (*ing)[b.y][b.x] > 0)) return false;  // 原料格不可换
    swap_cells(g, a, b);
    bool found = !find_matches_ingredient(g, coat, choco, ing).empty();
    swap_cells(g, a, b);
    return found;
}

// 数原料格总数。
inline int count_ingredients(const std::vector<std::vector<int>>& ing) {
    int n = 0;
    for (const auto& row : ing)
        for (int v : row)
            if (v > 0) ++n;
    return n;
}

// 收集出口处的原料：exit_cols 列在物理最底行(y=h-1)若是原料(ing>0)则收集——
//   grid 该格清空(EMPTY)、ing 归 0，返回本次收集格数。原地改 g/ing。
inline int collect_ingredients_at_exit(Grid& g, std::vector<std::vector<int>>& ing,
                                       const std::vector<int>& exit_cols) {
    int h = (int)g.size();
    if (h == 0 || ing.empty()) return 0;
    int w = (int)g[0].size();
    int by = h - 1;   // 物理最底行 = 出口所在行
    int collected = 0;
    for (int cx : exit_cols) {
        if (cx < 0 || cx >= w) continue;
        if (ing[by][cx] > 0) {
            g[by][cx] = EMPTY;
            ing[by][cx] = 0;
            ++collected;
        }
    }
    return collected;
}

// 原料下沉收集循环：先重力沉底，再"收出口→重力"直到无新原料被收。返回累计收集数。
//   镜像 GDScript _drain_ingredients：纯重力不触发 match 循环，故消除稳定后单独跑把原料送进出口。
inline int drain_ingredients(Grid& g, const std::vector<std::vector<int>>* coat,
                             const std::vector<std::vector<int>>* choco,
                             std::vector<std::vector<int>>& ing,
                             const std::vector<int>& exit_cols) {
    if (ing.empty() || exit_cols.empty()) return 0;
    int collected = 0;
    apply_gravity_ingredient(g, coat, choco, &ing);   // 先沉底：悬空原料送到最低处（含出口行）
    while (true) {
        int got = collect_ingredients_at_exit(g, ing, exit_cols);
        if (got == 0) break;
        collected += got;
        apply_gravity_ingredient(g, coat, choco, &ing);   // 收掉出口原料→让位→上方继续沉
    }
    return collected;
}

struct IngResolveResult {
    int score = 0, cascades = 0, cleared = 0;
    int jelly_cleared = 0, blocker_cleared = 0, ingredient_collected = 0;
    std::vector<int> by_species;
    bool operator==(const IngResolveResult& o) const {
        return score == o.score && cascades == o.cascades && cleared == o.cleared
               && jelly_cleared == o.jelly_cleared && blocker_cleared == o.blocker_cleared
               && ingredient_collected == o.ingredient_collected && by_species == o.by_species;
    }
};

// ing 感知的 resolve：消除→计分→下落(原料随重力落)→收出口→补充，循环至稳定；末尾把落定原料排进出口。
//   返回含 ingredient_collected = 本次结算落到出口被收的原料数。镜像 GDScript _resolve_plain 的 ing 分支。
inline IngResolveResult resolve_ingredient(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                                           std::vector<std::vector<int>>* jelly,
                                           std::vector<std::vector<int>>* coat,
                                           std::vector<std::vector<int>>* choco,
                                           std::vector<std::vector<int>>* ing,
                                           const std::vector<int>& exit_cols,
                                           std::vector<std::deque<int>>* feed = nullptr,
                                           bool do_refill = true) {
    IngResolveResult r;
    while (true) {
        auto matched = find_matches_ingredient(g, coat, choco, ing);
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
        apply_gravity_ingredient(g, coat, choco, ing);   // 原料随重力下落（ing 随 grid 同步移动）
        if (ing) r.ingredient_collected += collect_ingredients_at_exit(g, *ing, exit_cols);
        if (do_refill) refill(g, species, rng, feed);
    }
    // 消除稳定后，把仍悬在出口上方、已落定的原料一路沉到出口收掉。
    if (ing) {
        r.ingredient_collected += drain_ingredients(g, coat, choco, *ing, exit_cols);
        if (do_refill) refill(g, species, rng, feed);
    }
    return r;
}

// ───────────── 倒计时炸弹（Bomb）：C++ 镜像（仅新增函数，不改现有签名）─────────────
// 炸弹语义（与 godot/core/match_engine.gd 一一对应）—— 它是障碍层里【唯一可被三消/特效直接消除】的：
//   炸弹格的 grid 是【普通棋子 species】（可消、可换、随重力下落），bomb[y][x]=N 只是叠加的剩余 N 步倒计时。
//   故炸弹【不感知于 find_matches/is_legal_swap】（炸弹格当普通棋子参与匹配/交换，无需 *_bomb 的匹配/交换版本）。
//   ① 消除拆弹：炸弹格被消除 → bomb→0（resolve_bomb 在清格处同步清）。
//   ② 随重力下落：bomb 作为纯标记随 grid 同步搬运（apply_gravity_bomb，与 ingredient 同构的"标记跟随"）。
//   ③ 每步递减：有效交换后所有 bomb>0 -1（tick_bombs，由上层 board 在消耗步数处调）。
//   ④ 归零判负：某 bomb 递减到 0 且未被消除 → 引爆 → 对局立即失败（上层据 tick 返回置失败态）。

// bomb 感知的重力：炸弹格的 grid 是普通棋子，bomb 作为纯标记【随 grid 同步搬运】（不切段）。
//   仅墙/锁住格(coat>0)/巧克力格(choco>0)切段固定；炸弹自身不切段（它是段内可动元素）。
//   与 apply_gravity_ingredient 同构：bomb 标记随该格内容一起落。
inline void apply_gravity_bomb(Grid& g, const std::vector<std::vector<int>>* coat,
                               const std::vector<std::vector<int>>* choco,
                               std::vector<std::vector<int>>* bomb) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    for (int x = 0; x < w; ++x) {
        int seg_start = 0;
        for (int y = 0; y <= h; ++y) {
            bool fixed = (y < h) && ((coat && (*coat)[y][x] > 0) || (choco && (*choco)[y][x] > 0));
            if (y == h || g[y][x] == WALL || fixed) {
                std::vector<int> stack;        // 段内非空 species
                std::vector<int> bomb_stack;   // 段内每个可动格的炸弹倒计时，随 stack 同序搬运
                for (int k = seg_start; k < y; ++k)
                    if (g[k][x] != EMPTY) {
                        stack.push_back(g[k][x]);
                        if (bomb) bomb_stack.push_back((*bomb)[k][x]);
                    }
                int seg_len = y - seg_start;
                int empties = seg_len - (int)stack.size();
                for (int k = seg_start; k < y; ++k) {
                    int idx = k - seg_start;
                    if (idx < empties) {
                        g[k][x] = EMPTY;
                        if (bomb) (*bomb)[k][x] = 0;            // 空格无炸弹
                    } else {
                        g[k][x] = stack[idx - empties];
                        if (bomb) (*bomb)[k][x] = bomb_stack[idx - empties];  // 炸弹倒计时随该格内容一起落
                    }
                }
                seg_start = y + 1;
            }
        }
    }
}

// 每步倒计时递减：所有 bomb>0 的格 -1。返回本次有几个炸弹【因递减而归零】（即引爆数）。原地改 bomb。
inline int tick_bombs(std::vector<std::vector<int>>& bomb) {
    int exploded = 0;
    for (auto& row : bomb)
        for (int& v : row)
            if (v > 0) {
                --v;
                if (v == 0) ++exploded;  // 这步递减到 0 = 引爆（该格本步未被消除拆弹才会走到这）
            }
    return exploded;
}

// 数盘上还在倒计时的炸弹格总数。
inline int count_bombs(const std::vector<std::vector<int>>& bomb) {
    int n = 0;
    for (const auto& row : bomb)
        for (int v : row)
            if (v > 0) ++n;
    return n;
}

struct BombResolveResult {
    int score = 0, cascades = 0, cleared = 0;
    int jelly_cleared = 0, blocker_cleared = 0, bomb_defused = 0;
    std::vector<int> by_species;
    bool operator==(const BombResolveResult& o) const {
        return score == o.score && cascades == o.cascades && cleared == o.cleared
               && jelly_cleared == o.jelly_cleared && blocker_cleared == o.blocker_cleared
               && bomb_defused == o.bomb_defused && by_species == o.by_species;
    }
};

// bomb 感知的 resolve：消除→拆弹(消除格 bomb→0)→计分→下落(炸弹随重力落)→补充，循环至稳定。原地改 g/coat/bomb。
//   返回含 bomb_defused = 本次结算因消除而拆掉的炸弹数。镜像 GDScript _resolve_plain 的 bomb 分支。
//   炸弹格是普通棋子 → 用基础 find_matches(coat 感知；炸弹不感知)，与 GDScript 纯炸弹关行为一致。
inline BombResolveResult resolve_bomb(Grid& g, const std::vector<int>& species, std::mt19937& rng,
                                      std::vector<std::vector<int>>* jelly = nullptr,
                                      std::vector<std::vector<int>>* coat = nullptr,
                                      std::vector<std::vector<int>>* bomb = nullptr,
                                      std::vector<std::deque<int>>* feed = nullptr,
                                      bool do_refill = true) {
    BombResolveResult r;
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
        for (const auto& p : matched) {
            int s = g[p.y][p.x];
            if (s >= 0) {
                if ((int)r.by_species.size() <= s) r.by_species.resize(s + 1, 0);
                r.by_species[s]++;
            }
            if (jelly && (*jelly)[p.y][p.x] > 0) { (*jelly)[p.y][p.x]--; r.jelly_cleared++; }
            if (bomb && (*bomb)[p.y][p.x] > 0) {   // 炸弹格被消除 → 拆弹（bomb 归 0）
                (*bomb)[p.y][p.x] = 0;
                r.bomb_defused++;
            }
            g[p.y][p.x] = EMPTY;
        }
        r.cleared += (int)matched.size();
        r.score += score_for_clear((int)matched.size(), r.cascades);
        apply_gravity_bomb(g, coat, nullptr, bomb);   // 炸弹随重力下落（bomb 随 grid 同步移动）
        if (do_refill) refill(g, species, rng, feed);
    }
    return r;
}

// ───────────── 糖果炮（Candy Cannon）：C++ 镜像（仅新增函数，不改现有签名）─────────────
// 炮口语义（与 godot/core/match_engine.gd 一一对应）—— 复用 WALL，故 find_matches/apply_gravity/is_legal_swap 全不感知 cannon：
//   炮口格的 grid 是【WALL(-2)】（不可消/不可动/不下落/切段），cannon[y][x] 只是叠加的"这格是炮 + 产出类型"标记：
//     cannon[y][x]=0 无炮；=1 产普通糖；=2 产原料。
//   每【有效】交换结算后，每个炮口格在其正下方相邻格(y+1) 若 EMPTY 则产一个棋子（下方非空则本步不产、等位置空出）：
//     cannon=1 → 普通糖（grid=随机 species）；cannon=2 → 原料（grid=随机 species 且 ing[y+1]=1）。
//   产出物随后自然下落（由上层 board 在产出后调 apply_gravity_* 沉底）。RNG 各端独立，不要求跨语言同序列。

// 从所有炮口产出：每个 cannon>0 的格在其正下方(y+1)空格产一个随机 species 棋子。
//   cannon=2 且传入 ing → 产出格 ing=1（产原料炮）。下方非空或越界则该炮本步不产。
//   用注入的 rng（确定性可复现）。返回本次产出的棋子总数。原地改 g（与 ing，若传入）。
inline int spawn_from_cannons(const std::vector<std::vector<int>>& cannon, Grid& g,
                              const std::vector<int>& species, std::mt19937& rng,
                              std::vector<std::vector<int>>* ing = nullptr) {
    int h = (int)cannon.size();
    if (h == 0) return 0;
    int w = (int)cannon[0].size();
    if (species.empty()) return 0;
    std::uniform_int_distribution<int> dist(0, (int)species.size() - 1);
    int produced = 0;
    for (int y = 0; y < h; ++y)
        for (int x = 0; x < w; ++x) {
            if (cannon[y][x] <= 0) continue;
            int by = y + 1;
            if (by >= h) continue;             // 炮口在最底行：下方无格可产
            if (g[by][x] != EMPTY) continue;   // 下方非空 → 本步不产
            g[by][x] = species[dist(rng)];     // 产出一个随机 species 棋子
            if (cannon[y][x] == 2 && ing) (*ing)[by][x] = 1;  // 产原料炮：产出格打原料标记
            ++produced;
        }
    return produced;
}

// 数盘上的炮口格总数（cannon[y][x]>0 即一门炮）。
inline int count_cannons(const std::vector<std::vector<int>>& cannon) {
    int n = 0;
    for (const auto& row : cannon)
        for (int v : row)
            if (v > 0) ++n;
    return n;
}

// ───────────── 爆米花（Popcorn）：C++ 镜像（仅新增函数，不改现有签名）─────────────
// 爆米花语义（与 godot/core/match_engine.gd 一一对应）—— 与 coat/choco 不同：普通三消【完全不碰】它，只有特效命中才递减：
//   爆米花格 grid 是普通 species(占位)、popcorn[y][x]=N(剩余命中数)；不参与匹配/不可交换/随重力下落；
//   被【特效清除波及】(格自身在清除集)时 popcorn-1(不清)，归0变彩球。
// 说明：特效(条纹/爆炸/彩球)与"归0变彩球"是 Godot 侧专属（C++ 裸 Core 不实现特效，已在文件头声明），
//   故 C++ 镜像只覆盖【不依赖特效的机械原语】：匹配跳过(find_matches_popcorn)、不可换(is_legal_swap_popcorn)、
//   随重力下落(apply_gravity_popcorn)、命中递减(hit_popcorn，按"格在清除集"减一，归0不在此层变彩球)、计数(count_popcorn)。
// 障碍判定沿用 coat>0/choco>0/ing>0 表达"不可消/不可换"，爆米花再叠一层 popcorn>0；提供独立 *_popcorn 版本。

// popcorn 感知的匹配：爆米花格(popcorn>0)与锁住/巧克力/原料格一样不参与匹配、断开同色串。
inline std::vector<Vec2> find_matches_popcorn(const Grid& g,
                                              const std::vector<std::vector<int>>* coat,
                                              const std::vector<std::vector<int>>* choco,
                                              const std::vector<std::vector<int>>* ing,
                                              const std::vector<std::vector<int>>* popcorn) {
    int h = (int)g.size();
    if (h == 0) return {};
    int w = (int)g[0].size();
    auto blocked = [&](int x, int y) -> bool {
        return g[y][x] == EMPTY || g[y][x] == WALL
            || (coat && (*coat)[y][x] > 0) || (choco && (*choco)[y][x] > 0)
            || (ing && (*ing)[y][x] > 0) || (popcorn && (*popcorn)[y][x] > 0);
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

// popcorn 感知的重力：爆米花格(popcorn>0)【随重力下落】——作为段内可动元素和 grid 一起搬运，popcorn 层与 grid 同步重排。
//   与 apply_gravity_ingredient/apply_gravity_bomb 同构（标记跟随）：仅墙/锁住/巧克力切段，爆米花自身不切段。
inline void apply_gravity_popcorn(Grid& g, const std::vector<std::vector<int>>* coat,
                                  const std::vector<std::vector<int>>* choco,
                                  std::vector<std::vector<int>>* popcorn) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    for (int x = 0; x < w; ++x) {
        int seg_start = 0;
        for (int y = 0; y <= h; ++y) {
            bool fixed = (y < h) && ((coat && (*coat)[y][x] > 0) || (choco && (*choco)[y][x] > 0));
            if (y == h || g[y][x] == WALL || fixed) {
                std::vector<int> stack;          // 段内非空 species
                std::vector<int> pop_stack;      // 段内每个可动格的爆米花命中数，随 stack 同序搬运
                for (int k = seg_start; k < y; ++k)
                    if (g[k][x] != EMPTY) {
                        stack.push_back(g[k][x]);
                        if (popcorn) pop_stack.push_back((*popcorn)[k][x]);
                    }
                int seg_len = y - seg_start;
                int empties = seg_len - (int)stack.size();
                for (int k = seg_start; k < y; ++k) {
                    int idx = k - seg_start;
                    if (idx < empties) {
                        g[k][x] = EMPTY;
                        if (popcorn) (*popcorn)[k][x] = 0;            // 空格无爆米花
                    } else {
                        g[k][x] = stack[idx - empties];
                        if (popcorn) (*popcorn)[k][x] = pop_stack[idx - empties];  // 爆米花命中数随该格内容一起落
                    }
                }
                seg_start = y + 1;
            }
        }
    }
}

// popcorn 感知的合法交换：爆米花格(popcorn>0)与锁住/巧克力/原料格一样不可参与交换。
inline bool is_legal_swap_popcorn(Grid& g, Vec2 a, Vec2 b,
                                  const std::vector<std::vector<int>>* coat,
                                  const std::vector<std::vector<int>>* choco,
                                  const std::vector<std::vector<int>>* ing,
                                  const std::vector<std::vector<int>>* popcorn) {
    if (std::abs(a.x - b.x) + std::abs(a.y - b.y) != 1) return false;
    int va = g[a.y][a.x], vb = g[b.y][b.x];
    if (va == WALL || vb == WALL || va == EMPTY || vb == EMPTY) return false;
    if (coat && ((*coat)[a.y][a.x] > 0 || (*coat)[b.y][b.x] > 0)) return false;
    if (choco && ((*choco)[a.y][a.x] > 0 || (*choco)[b.y][b.x] > 0)) return false;
    if (ing && ((*ing)[a.y][a.x] > 0 || (*ing)[b.y][b.x] > 0)) return false;
    if (popcorn && ((*popcorn)[a.y][a.x] > 0 || (*popcorn)[b.y][b.x] > 0)) return false;  // 爆米花格不可换
    swap_cells(g, a, b);
    bool found = !find_matches_popcorn(g, coat, choco, ing, popcorn).empty();
    swap_cells(g, a, b);
    return found;
}

// 特效命中爆米花：被特效清除波及(cleared 列表里的格【自身】)的爆米花格 popcorn-1（爆米花本身不被清）。原地改 popcorn，返回命中次数。
//   镜像 GDScript _hit_popcorn 的递减部分；归0变彩球(SP_COLORBOMB)是 Godot 特效层专属，C++ 裸 Core 不在此实现（归0后 popcorn=0 即可）。
//   与 eat_chocolate 的关键区别：只认"格自身在清除集"（巧克力认正交相邻）。
inline int hit_popcorn(std::vector<std::vector<int>>& popcorn,
                       const std::vector<Vec2>& cleared) {
    int h = (int)popcorn.size();
    if (h == 0) return 0;
    int w = (int)popcorn[0].size();
    int hits = 0;
    for (const auto& p : cleared) {
        if (p.x < 0 || p.x >= w || p.y < 0 || p.y >= h) continue;
        if (popcorn[p.y][p.x] > 0) {
            popcorn[p.y][p.x]--;
            ++hits;
        }
    }
    return hits;
}

// 数盘上还剩命中数的爆米花格总数（归0已变彩球的格 popcorn=0 不计）。
inline int count_popcorn(const std::vector<std::vector<int>>& popcorn) {
    int n = 0;
    for (const auto& row : popcorn)
        for (int v : row)
            if (v > 0) ++n;
    return n;
}

}  // namespace me
