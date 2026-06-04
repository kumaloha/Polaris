#pragma once
// match_engine.hpp — 消除 Core 规则的 C++ 镜像（与 godot/core/match_engine.gd 一一对应）。
// 这是 09 护城河的地基：求解器/生成器都基于这套规则。grid[y][x]，坐标 Vec2{x,y}。
#include <vector>
#include <random>
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
inline std::vector<Vec2> find_matches(const Grid& g) {
    int h = (int)g.size();
    if (h == 0) return {};
    int w = (int)g[0].size();
    std::vector<std::vector<char>> mark(h, std::vector<char>(w, 0));
    // 横向串（跳过 EMPTY 和 WALL：它们不参与消除、也不能让墙连成串）
    for (int y = 0; y < h; ++y) {
        int x = 0;
        while (x < w) {
            if (g[y][x] == EMPTY || g[y][x] == WALL) { ++x; continue; }
            int e = x;
            while (e + 1 < w && g[y][e + 1] == g[y][x]) ++e;
            if (e - x + 1 >= 3)
                for (int k = x; k <= e; ++k) mark[y][k] = 1;
            x = e + 1;
        }
    }
    // 纵向串
    for (int x = 0; x < w; ++x) {
        int y = 0;
        while (y < h) {
            if (g[y][x] == EMPTY || g[y][x] == WALL) { ++y; continue; }
            int e = y;
            while (e + 1 < h && g[e + 1][x] == g[y][x]) ++e;
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
inline void apply_gravity(Grid& g) {
    int h = (int)g.size();
    if (h == 0) return;
    int w = (int)g[0].size();
    for (int x = 0; x < w; ++x) {
        int seg_start = 0;
        for (int y = 0; y <= h; ++y) {
            if (y == h || g[y][x] == WALL) {
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
inline void refill(Grid& g, const std::vector<int>& species, std::mt19937& rng) {
    std::uniform_int_distribution<int> dist(0, (int)species.size() - 1);
    for (auto& row : g)
        for (int& v : row)
            if (v == EMPTY) v = species[dist(rng)];
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
    bool found = !find_matches(g).empty();
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
                             std::vector<std::vector<int>>* coat = nullptr) {
    ResolveResult r;
    while (true) {
        auto matched = find_matches(g);
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
        apply_gravity(g);
        refill(g, species, rng);
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

}  // namespace me
