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

int main() {
    test_find_horizontal_three();
    test_gravity_pulls_tiles_down();
    test_refill_fills_within_species();
    test_refill_deterministic();
    test_score_escalates();
    test_legal_swap();
    test_has_legal_move();
    test_resolve();
    test_resolve_deterministic();
    test_make_board();
    return report();
}
