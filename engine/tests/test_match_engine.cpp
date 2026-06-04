// C++ 引擎单测（镜像 godot/tests/test_match_engine.gd 的用例，保证两端规则一致）。
#include "check.hpp"
#include "../include/match_engine.hpp"

using namespace me;

static bool has(const std::vector<Vec2>& v, Vec2 p) {
    for (const auto& c : v)
        if (c == p) return true;
    return false;
}

// grid[y][x]，坐标 Vec2{x,y}
static void test_find_horizontal_three() {
    Grid g = {
        {0, 0, 0, 1},
        {1, 2, 3, 2},
        {2, 3, 1, 0},
    };
    auto m = find_matches(g);
    CHECK_EQ((int)m.size(), 3, "find_horizontal_three: exactly 3 matched");
    CHECK(has(m, {0, 0}), "has (0,0)");
    CHECK(has(m, {1, 0}), "has (1,0)");
    CHECK(has(m, {2, 0}), "has (2,0)");
}

static void test_gravity_pulls_tiles_down() {
    Grid g = {{1, EMPTY, 2}, {EMPTY, EMPTY, 3}, {4, 5, EMPTY}};
    apply_gravity(g);
    Grid want = {{EMPTY, EMPTY, EMPTY}, {1, EMPTY, 2}, {4, 5, 3}};
    CHECK(g == want, "gravity drops tiles to column bottom");
}

static void test_refill_fills_within_species() {
    Grid g = {{EMPTY, 1, EMPTY}, {2, EMPTY, 3}};
    std::mt19937 rng(12345);
    std::vector<int> sp = {0, 1, 2, 3};
    refill(g, sp, rng);
    bool no_empty = true, in_set = true;
    for (auto& row : g)
        for (int v : row) {
            if (v == EMPTY) no_empty = false;
            bool found = false;
            for (int s : sp) if (s == v) found = true;
            if (!found) in_set = false;
        }
    CHECK(no_empty, "refill leaves no EMPTY");
    CHECK(in_set, "refill values within species");
    CHECK_EQ(g[0][1], 1, "existing tile kept");
    CHECK_EQ(g[1][0], 2, "existing tile kept");
}

static void test_refill_deterministic() {
    Grid a = {{EMPTY, EMPTY, EMPTY}, {EMPTY, EMPTY, EMPTY}};
    Grid b = a;
    std::mt19937 r1(99), r2(99);
    std::vector<int> sp = {0, 1, 2, 3, 4};
    refill(a, sp, r1);
    refill(b, sp, r2);
    CHECK(a[0][0] != EMPTY, "refill actually fills (sanity)");
    CHECK(a == b, "same seed -> identical refill");
}

static void test_score_escalates() {
    CHECK_EQ(score_for_clear(3, 1), 30, "3x10x1");
    CHECK_EQ(score_for_clear(4, 2), 80, "4x10x2");
    CHECK_EQ(score_for_clear(5, 3), 150, "5x10x3");
}

static void test_legal_swap() {
    Grid g = {{0, 0, 1}, {1, 2, 0}, {3, 4, 5}};
    CHECK(is_legal_swap(g, {2, 0}, {2, 1}), "swap forms 0,0,0 -> legal");
    Grid g2 = {{0, 1, 2}, {3, 4, 5}, {6, 7, 8}};
    CHECK(!is_legal_swap(g2, {0, 0}, {1, 0}), "no match formed -> illegal");
    Grid g3 = {{5, 0, 0, 1}, {2, 3, 4, 6}, {0, 7, 8, 9}};
    CHECK(!is_legal_swap(g3, {0, 0}, {0, 2}), "non-adjacent -> illegal");
}

static void test_has_legal_move() {
    Grid g = {{0, 0, 1}, {1, 2, 0}, {3, 4, 5}};
    CHECK(has_legal_move(g), "a legal swap exists");
    Grid g2 = {{0, 1, 2}, {3, 4, 5}, {6, 7, 8}};
    CHECK(!has_legal_move(g2), "all distinct -> deadlock");
}

static void test_resolve() {
    Grid stable = {{0, 1, 0}, {1, 0, 1}, {0, 1, 0}};
    std::mt19937 rng(1);
    std::vector<int> sp = {0, 1, 2, 3};
    auto r = resolve(stable, sp, rng);
    CHECK_EQ(r.score, 0, "stable grid scores 0");
    CHECK_EQ(r.cascades, 0, "stable grid no cascades");

    Grid m = {{0, 0, 0, 1}, {1, 2, 3, 2}, {2, 3, 1, 3}, {3, 1, 2, 1}};
    std::mt19937 rng2(42);
    auto r2 = resolve(m, sp, rng2);
    CHECK(r2.score >= 30, "initial 3-match scores >= 30");
    CHECK(r2.cascades >= 1, "at least one cascade");
    CHECK(find_matches(m).empty(), "board stable after resolve");
}

static void test_resolve_deterministic() {
    Grid a = {{0, 0, 0, 1}, {1, 2, 3, 2}, {2, 3, 1, 3}, {3, 1, 2, 1}};
    Grid b = a;
    std::mt19937 r1(7), r2(7);
    std::vector<int> sp = {0, 1, 2, 3};
    auto ra = resolve(a, sp, r1);
    auto rb = resolve(b, sp, r2);
    CHECK(ra.score > 0, "scored (sanity)");
    CHECK(ra == rb, "same seed -> same result");
    CHECK(a == b, "same seed -> same grid");
}

static void test_make_board() {
    std::mt19937 rng(123);
    auto g = make_board(8, 8, {0, 1, 2, 3, 4}, rng);
    CHECK_EQ((int)g.size(), 8, "height 8");
    if ((int)g.size() != 8) return;  // 空盘守卫（RED 阶段防越界）
    CHECK_EQ((int)g[0].size(), 8, "width 8");
    CHECK(find_matches(g).empty(), "no initial match");
    CHECK(has_legal_move(g), "start board has a legal move");
    std::mt19937 r1(5), r2(5);
    auto g1 = make_board(6, 6, {0, 1, 2, 3}, r1);
    auto g2 = make_board(6, 6, {0, 1, 2, 3}, r2);
    CHECK(g1 == g2, "same seed -> identical board");
}

// ---- A①：战场切割/异形棋盘（WALL） ----

static void test_find_matches_ignores_walls() {
    Grid g = {
        {WALL, WALL, WALL, 0},  // 三面墙连排，绝不能算消除
        {1, 2, 3, 0},
        {1, 2, 3, 0},           // 第3列 0,0,0 是真正的竖三连
    };
    auto m = find_matches(g);
    CHECK_EQ((int)m.size(), 3, "only the real match; walls never match");
    for (const auto& p : m) CHECK(g[p.y][p.x] != WALL, "no wall cell in matches");
}

static void test_gravity_respects_wall_segments() {
    Grid g = {{1}, {EMPTY}, {WALL}, {EMPTY}, {2}};  // 单列：墙把列分成上下两段
    apply_gravity(g);
    Grid want = {{EMPTY}, {1}, {WALL}, {EMPTY}, {2}};
    CHECK(g == want, "tiles fall within wall-bounded segments; wall stays put");
}

static void test_swap_wall_is_illegal() {
    // 没墙时 (2,0)<->(2,1) 合法；把 (2,0) 变成墙后，即使交换会凑出三连也非法（墙不可动）
    Grid gw = {{0, 0, WALL}, {1, 2, 0}, {3, 4, 5}};
    CHECK(!is_legal_swap(gw, {2, 0}, {2, 1}), "moving a WALL is illegal even if tiles would match");
}

static void test_resolve_reports_by_species() {
    Grid g = {{0, 0, 0, 1}, {1, 2, 3, 2}, {2, 3, 1, 3}};  // 顶行三个 0
    std::mt19937 rng(1);
    auto r = resolve(g, {0, 1, 2, 3}, rng);
    int sum = 0;
    for (int c : r.by_species) sum += c;
    CHECK_EQ(sum, r.cleared, "by_species sums to total cleared");
    CHECK(r.by_species.size() > 0 && r.by_species[0] >= 3, "the three species-0 cells are counted");
}

static void test_coat_blocks_swap() {
    Grid g = {{0, 0, 1}, {1, 2, 0}, {3, 4, 5}};  // (2,0)<->(2,1) 本来合法
    std::vector<std::vector<int>> coat(3, std::vector<int>(3, 0));
    coat[0][2] = 1;  // (2,0) 被涂层冻住
    CHECK(!is_legal_swap(g, {2, 0}, {2, 1}, &coat), "coated cell can't be swapped");
    CHECK(is_legal_swap(g, {2, 0}, {2, 1}, nullptr), "no coat ptr -> normal legal");
}

static void test_find_matches_skips_locked() {
    // 经典锁：锁住格(coat>0)不可匹配，断开同色串。
    Grid g = {{0, 0, 0, 1}, {2, 3, 4, 2}, {3, 4, 2, 3}};
    CHECK_EQ((int)find_matches(g).size(), 3, "no coat -> top row is a 3-match");
    std::vector<std::vector<int>> coat(3, std::vector<int>(4, 0));
    coat[0][1] = 1;  // 锁住顶行中间格 -> 0 [L]0 0 断串
    CHECK(find_matches(g, &coat).empty(), "locked middle breaks the run -> no match");
}

static void test_gravity_blocks_locked() {
    // 锁住格在重力下固定：上方棋子不会穿过它下落（段隔离）。
    Grid col = {{0}, {6}, {EMPTY}};  // 列：[0, 6(锁), EMPTY]
    std::vector<std::vector<int>> coat = {{0}, {1}, {0}};  // (0,1) 锁住
    apply_gravity(col, &coat);
    CHECK_EQ(col[0][0], 0, "tile above lock stays (can't fall through the lock)");
    CHECK_EQ(col[1][0], 6, "locked cell stays put under gravity");
    CHECK_EQ(col[2][0], EMPTY, "below-lock empty stays empty");
}

static void test_resolve_locked_broken_by_adjacency() {
    // 锁住格不参与消除，靠相邻消除破锁(每次-1)，破锁前 tile 不被清、不下落。
    Grid g = {{0, 0, 0, 1}, {2, 1, 3, 2}, {3, 4, 2, 3}};
    std::vector<std::vector<int>> coat(3, std::vector<int>(4, 0));
    coat[1][0] = 5;  // (0,1) 锁 5 层，紧邻顶行消除（其正下方）
    std::mt19937 rng(1);
    auto r = resolve(g, {0, 1, 2, 3}, rng, nullptr, &coat);
    CHECK(r.blocker_cleared >= 1, "adjacent clear breaks at least one lock layer");
    CHECK(coat[1][0] < 5 && coat[1][0] > 0, "lock decreased but still locked");
    CHECK_EQ(g[1][0], 2, "locked tile preserved (never cleared/moved while locked)");
}

static void test_make_board_with_wall_mask() {
    int W = 6, H = 6;
    std::vector<std::vector<char>> mask(H, std::vector<char>(W, 0));
    mask[0][0] = 1; mask[2][3] = 1; mask[5][5] = 1;  // 3 个洞
    std::mt19937 rng(7);
    auto g = make_board(W, H, {0, 1, 2, 3, 4}, rng, mask);
    CHECK(g[0][0] == WALL && g[2][3] == WALL && g[5][5] == WALL, "walls at masked cells");
    int walls = 0;
    for (auto& r : g) for (int v : r) if (v == WALL) walls++;
    CHECK_EQ(walls, 3, "exactly the masked walls, no others");
    CHECK(find_matches(g).empty(), "no initial match on the irregular board");
    CHECK(has_legal_move(g), "irregular board still has a legal move");
}

static void test_reshuffle_keeps_walls() {
    // 镜像 GDScript：洗牌只重排可动棋子，墙原地不动、可动多重集不变。
    Grid g = {
        {WALL, 1, 2, 3, 0, 1},
        {0, 1, 2, 3, 0, 1},
        {2, 3, 0, WALL, 2, 3},
        {1, 2, 3, 0, 1, 2},
        {3, 0, 1, 2, 3, 0},
        {WALL, 1, 2, 3, 0, WALL},
    };
    std::vector<int> before;
    int walls_before = 0;
    for (auto& r : g) for (int v : r) { if (v == WALL) ++walls_before; else before.push_back(v); }
    std::sort(before.begin(), before.end());
    std::mt19937 rng(5);
    reshuffle(g, rng);
    CHECK(g[0][0] == WALL && g[2][3] == WALL && g[5][0] == WALL && g[5][5] == WALL,
          "walls stay put after reshuffle");
    std::vector<int> after;
    int walls_after = 0;
    for (auto& r : g) for (int v : r) { if (v == WALL) ++walls_after; else after.push_back(v); }
    std::sort(after.begin(), after.end());
    CHECK_EQ(walls_after, walls_before, "wall count unchanged");
    CHECK(before == after, "movable tile multiset preserved");
    CHECK(find_matches(g).empty(), "no ready match after reshuffle");
}

static void test_reshuffle_coat_aware() {
    // 洗牌验收须 coat 感知：后置条件 = 无现成消除 且 有 coat 合法步。
    Grid g;
    for (int y = 0; y < 6; ++y) {
        std::vector<int> row;
        for (int x = 0; x < 6; ++x) row.push_back((x * 2 + y) % 5);
        g.push_back(row);
    }
    std::vector<std::vector<int>> coat(6, std::vector<int>(6, 0));
    coat[0][0] = 1; coat[2][3] = 1; coat[4][1] = 1; coat[5][5] = 1;
    std::mt19937 rng(9);
    reshuffle(g, rng, &coat);
    CHECK(find_matches(g).empty(), "no ready match after coat-aware reshuffle");
    CHECK(has_legal_move(g, &coat), "coat-aware legal move exists after reshuffle");
}

int main() {
    test_find_horizontal_three();
    test_find_matches_ignores_walls();
    test_gravity_respects_wall_segments();
    test_swap_wall_is_illegal();
    test_resolve_reports_by_species();
    test_coat_blocks_swap();
    test_find_matches_skips_locked();
    test_gravity_blocks_locked();
    test_resolve_locked_broken_by_adjacency();
    test_make_board_with_wall_mask();
    test_gravity_pulls_tiles_down();
    test_refill_fills_within_species();
    test_refill_deterministic();
    test_score_escalates();
    test_legal_swap();
    test_has_legal_move();
    test_resolve();
    test_resolve_deterministic();
    test_make_board();
    test_reshuffle_keeps_walls();
    test_reshuffle_coat_aware();
    return report();
}
