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

// 滚动补充：refill 从 feed 每列前端取(自上而下)，feed 随之缩短；feed 空的列回退随机。
static void test_refill_from_feed() {
    Grid g = {{EMPTY, EMPTY}, {EMPTY, EMPTY}};
    std::vector<int> species = {0, 1, 2, 3, 4};
    std::vector<std::deque<int>> feed(2);
    feed[0] = {7, 8};   // 列0：先 7(上行) 后 8(下行)；用越界值 7/8 证明 feed 原样穿过
    std::mt19937 rng(1);
    refill(g, species, rng, &feed);
    CHECK_EQ(g[0][0], 7, "refill: feed col0 top = first queued item");
    CHECK_EQ(g[1][0], 8, "refill: feed col0 bottom = second queued item");
    CHECK(feed[0].empty(), "refill: feed col0 drained");
    CHECK(g[0][1] == EMPTY, "refill: exhausted-feed col stays EMPTY (no new piece dropped at top)");
    CHECK(g[1][1] == EMPTY, "refill: exhausted-feed col stays EMPTY (no new piece dropped at top)");
    Grid g2 = {{EMPTY, EMPTY, EMPTY}};
    refill(g2, species, rng);  // feed=nullptr → 普通关纯随机，全填满(与旧行为一致)
    CHECK(g2[0][0] != EMPTY && g2[0][2] != EMPTY, "refill: no feed (normal level) = all random filled");
}

// ───────────── 巧克力蔓延（Chocolate）：C++ 镜像断言（两端语义一致）─────────────

static void test_choco_not_matched() {
    // 巧克力格(choco>0)不参与匹配、断开同色串（镜像 find_matches_skips_locked 的巧克力版）。
    Grid g = {{0, 0, 0, 1}, {2, 3, 4, 2}, {3, 4, 2, 3}};
    CHECK_EQ((int)find_matches_choco(g, nullptr, nullptr).size(), 3, "no choco -> top row is a 3-match");
    std::vector<std::vector<int>> choco(3, std::vector<int>(4, 0));
    choco[0][1] = 1;  // 巧克力盖住顶行中间格
    CHECK(find_matches_choco(g, nullptr, &choco).empty(), "chocolate cell breaks the run -> no match");
}

static void test_choco_blocks_swap() {
    Grid g = {{0, 0, 1}, {1, 2, 0}, {3, 4, 5}};  // (2,0)<->(2,1) 本来合法
    std::vector<std::vector<int>> choco(3, std::vector<int>(3, 0));
    choco[0][2] = 1;  // (2,0) 被巧克力覆盖
    CHECK(!is_legal_swap_choco(g, {2, 0}, {2, 1}, nullptr, &choco), "chocolate cell can't be swapped");
    CHECK(is_legal_swap_choco(g, {2, 0}, {2, 1}, nullptr, nullptr), "no choco ptr -> normal legal");
}

static void test_choco_blocks_gravity() {
    Grid col = {{0}, {6}, {EMPTY}};  // 列：[0, 6(巧克力), EMPTY]
    std::vector<std::vector<int>> choco = {{0}, {1}, {0}};  // (0,1) 巧克力
    apply_gravity_choco(col, nullptr, &choco);
    CHECK_EQ(col[0][0], 0, "tile above chocolate stays (can't fall through)");
    CHECK_EQ(col[1][0], 6, "chocolate cell stays put under gravity");
    CHECK_EQ(col[2][0], EMPTY, "below-chocolate empty stays empty");
}

static void test_eat_chocolate_direct() {
    // 啃食：被清除格内/相邻的巧克力 -1。
    std::vector<std::vector<int>> choco = {{1, 0, 1}, {0, 1, 0}, {0, 0, 0}};
    std::vector<Vec2> cleared = {{1, 0}};  // 清 (1,0)：相邻 (0,0)左 (2,0)右 (1,1)下
    int eaten = eat_chocolate(choco, cleared);
    CHECK_EQ(eaten, 3, "three adjacent/covered chocolates eaten");
    CHECK_EQ(choco[0][0], 0, "(0,0) 1->0");
    CHECK_EQ(choco[0][2], 0, "(2,0) 1->0");
    CHECK_EQ(choco[1][1], 0, "(1,1) 1->0");
}

static void test_resolve_choco_eaten_by_adjacency() {
    // 巧克力被相邻消除则 -1，巧克力本身不被清/不下落（镜像 resolve_locked_broken_by_adjacency）。
    Grid g = {{0, 0, 0, 1}, {2, 1, 3, 2}, {3, 4, 2, 3}};
    std::vector<std::vector<int>> choco(3, std::vector<int>(4, 0));
    choco[1][0] = 2;  // (0,1) 巧克力厚 2，紧邻顶行消除（其正下方）
    std::mt19937 rng(1);
    auto r = resolve_choco(g, {0, 1, 2, 3}, rng, nullptr, nullptr, &choco, nullptr, false);
    CHECK(r.choco_cleared >= 1, "adjacent clear eats at least one chocolate");
    CHECK(choco[1][0] < 2 && choco[1][0] > 0, "chocolate decreased but still present");
    CHECK_EQ(g[1][0], 2, "chocolate-covered tile preserved (never cleared/moved)");
}

static void test_spread_adds_one() {
    // 一块巧克力居中、四周普通棋子 → 蔓延必 +1。
    Grid g = {{0, 1, 2}, {3, 0, 4}, {1, 2, 3}};
    std::vector<std::vector<int>> choco(3, std::vector<int>(3, 0));
    choco[1][1] = 1;
    std::mt19937 rng(42);
    int before = count_chocolate(choco);
    bool ok = spread_chocolate(choco, g, rng);
    CHECK(ok, "spread succeeds when there is an invadable neighbor");
    CHECK_EQ(count_chocolate(choco), before + 1, "exactly one new chocolate cell");
}

static void test_spread_no_candidate() {
    // 四正交邻全是 墙/空 → 无可侵占格 → 蔓延失败、计数不变。
    Grid g = {{WALL, EMPTY, WALL}, {EMPTY, 5, EMPTY}, {WALL, EMPTY, WALL}};
    std::vector<std::vector<int>> choco(3, std::vector<int>(3, 0));
    choco[1][1] = 1;
    std::mt19937 rng(7);
    int before = count_chocolate(choco);
    bool ok = spread_chocolate(choco, g, rng);
    CHECK(!ok, "no invadable neighbor (all EMPTY/WALL) -> spread fails");
    CHECK_EQ(count_chocolate(choco), before, "count unchanged when spread fails");
}

static void test_spread_deterministic() {
    // 同 seed 两次蔓延结果一致（确定性，注入 rng）。
    Grid g = {{0, 1, 2, 3}, {4, 0, 1, 2}, {3, 4, 0, 1}, {2, 3, 4, 0}};
    std::vector<std::vector<int>> c1(4, std::vector<int>(4, 0)), c2(4, std::vector<int>(4, 0));
    c1[1][1] = 1; c1[2][2] = 1;
    c2[1][1] = 1; c2[2][2] = 1;
    std::mt19937 r1(12345), r2(12345);
    spread_chocolate(c1, g, r1);
    spread_chocolate(c2, g, r2);
    CHECK(c1 == c2, "same seed -> identical spread result");
}

static void test_resolve_choco_no_eat_far_clear() {
    // 远端消除不挨着巧克力 → choco_cleared==0（board 据此触发蔓延；引擎只报数）。
    Grid g = {{0, 0, 0, 1}, {2, 3, 4, 2}, {3, 4, 2, 3}, {1, 2, 3, 1}};
    std::vector<std::vector<int>> choco(4, std::vector<int>(4, 0));
    choco[3][3] = 1;  // 角落巧克力，远离顶行消除
    std::mt19937 rng(1);
    auto r = resolve_choco(g, {0, 1, 2, 3}, rng, nullptr, nullptr, &choco, nullptr, false);
    CHECK(r.cleared >= 3, "top row cleared (sanity)");
    CHECK_EQ(r.choco_cleared, 0, "far clear does not eat the corner chocolate");
    CHECK_EQ(choco[3][3], 1, "corner chocolate intact");
}

// ───────────── 运原料（Ingredients）镜像断言 ─────────────

static void test_ingredient_not_matched() {
    // 原料格(ing>0)不参与匹配、断开同色串（镜像 GDScript test_ingredient_not_matched）。
    Grid g = {{0, 0, 0, 1}, {2, 3, 4, 2}, {3, 4, 2, 3}};
    CHECK_EQ((int)find_matches_ingredient(g, nullptr, nullptr, nullptr).size(), 3, "no ingredient -> top row is a 3-match");
    std::vector<std::vector<int>> ing(3, std::vector<int>(4, 0));
    ing[0][1] = 1;  // 原料盖住顶行中间格
    CHECK(find_matches_ingredient(g, nullptr, nullptr, &ing).empty(), "ingredient cell breaks the run -> no match");
}

static void test_ingredient_blocks_swap() {
    Grid g = {{0, 0, 1}, {1, 2, 0}, {3, 4, 5}};
    std::vector<std::vector<int>> ing(3, std::vector<int>(3, 0));
    ing[0][2] = 1;  // (2,0) 被原料覆盖
    CHECK(!is_legal_swap_ingredient(g, {2, 0}, {2, 1}, nullptr, nullptr, &ing), "ingredient cell can't be swapped");
    CHECK(is_legal_swap_ingredient(g, {2, 0}, {2, 1}, nullptr, nullptr, nullptr), "no ingredient ptr -> normal legal");
}

static void test_ingredient_falls_under_gravity() {
    // 与 choco 最大不同：原料【随重力下落】（choco 固定不动）。列 [原料,空,空] → 原料沉到列底。
    Grid col = {{5}, {EMPTY}, {EMPTY}};
    std::vector<std::vector<int>> ing = {{1}, {0}, {0}};
    apply_gravity_ingredient(col, nullptr, nullptr, &ing);
    CHECK_EQ(col[2][0], 5, "ingredient tile fell to the column bottom");
    CHECK_EQ(ing[2][0], 1, "ing layer moved with the tile (now at bottom)");
    CHECK_EQ(col[0][0], EMPTY, "top is now empty");
    CHECK_EQ(ing[0][0], 0, "ing layer cleared at the old top cell");
}

static void test_collect_at_exit_direct() {
    // 收集纯函数：最底行出口列若是原料 → 收集（grid 清空、ing 归 0）。
    Grid g = {{0, 1, 2}, {3, 4, 5}, {6, 7, 8}};
    std::vector<std::vector<int>> ing(3, std::vector<int>(3, 0));
    ing[2][0] = 1; ing[2][2] = 1;  // 两个原料在最底行
    int got = collect_ingredients_at_exit(g, ing, {0, 2});
    CHECK_EQ(got, 2, "two ingredients at exit collected");
    CHECK_EQ(g[2][0], EMPTY, "collected cell cleared to EMPTY");
    CHECK_EQ(ing[2][0], 0, "ing layer zeroed at collected cell");
    CHECK_EQ(count_ingredients(ing), 0, "no ingredients remain");
}

static void test_collect_respects_exit_cols() {
    // 非出口列的底行原料不被收集。
    Grid g = {{0, 1, 2}, {3, 4, 5}, {6, 7, 8}};
    std::vector<std::vector<int>> ing(3, std::vector<int>(3, 0));
    ing[2][1] = 1;  // (1,2) 在最底行但列1不是出口
    int got = collect_ingredients_at_exit(g, ing, {0, 2});
    CHECK_EQ(got, 0, "ingredient in non-exit column not collected");
    CHECK_EQ(ing[2][1], 1, "ingredient stays");
}

static void test_resolve_ingredient_sinks_to_bottom() {
    // 原料连续下沉到最底行 → 被收集，ingredient_collected==1，grid 该格清空（断言②）。
    // 列0 全空 → 原料从顶 (0,0) 落到底 (0,3) 出口被收。
    Grid g = {
        {5, 0, 1, 2},
        {EMPTY, 3, 4, 0},
        {EMPTY, 1, 2, 3},
        {EMPTY, 4, 0, 1},
    };
    std::vector<std::vector<int>> ing(4, std::vector<int>(4, 0));
    ing[0][0] = 1;
    std::mt19937 rng(1);
    auto r = resolve_ingredient(g, {0, 1, 2, 3, 4, 5}, rng, nullptr, nullptr, nullptr, &ing, {0, 1, 2, 3}, nullptr, false);
    CHECK_EQ(r.ingredient_collected, 1, "ingredient sank to bottom exit and got collected");
    CHECK_EQ(count_ingredients(ing), 0, "ingredient removed from board");
    CHECK_EQ(g[3][0], EMPTY, "exit cell cleared after collection");
}

static void test_resolve_ingredient_sinks_one_after_clear() {
    // 原料正下方棋子被消除 → 原料下沉一格（断言①）。
    // 原料在 (1,1)；正下方 (1,2) 属于第2行三连 7,7,7。消除 → (1,2) 空 → 原料沉到 (1,2)。
    Grid g = {
        {0, 1, 2, 3},
        {4, 9, 6, 0},
        {7, 7, 7, 1},
        {2, 3, 4, 5},
    };
    std::vector<std::vector<int>> ing(4, std::vector<int>(4, 0));
    ing[1][1] = 1;
    std::mt19937 rng(1);
    // 无出口(exit 空) → 只看下沉、不收集、不补充。
    auto r = resolve_ingredient(g, {0, 1, 2, 3, 4, 5, 6, 7, 9}, rng, nullptr, nullptr, nullptr, &ing, {}, nullptr, false);
    CHECK_EQ(ing[2][1], 1, "ingredient sank exactly one row (y=1 -> y=2)");
    CHECK_EQ(g[2][1], 9, "ingredient-covered tile moved down with it (species 9 preserved)");
    CHECK_EQ(ing[1][1], 0, "old ingredient cell cleared");
    CHECK_EQ(r.ingredient_collected, 0, "no exit configured -> nothing collected");
}

static void test_resolve_ingredient_deterministic() {
    // 同 seed 两次完整 resolve（含下落+收集+补充）结果一致（断言④）。
    auto mk = []() {
        return Grid{
            {0, 1, 9, 3},
            {4, 5, 0, 1},
            {2, 3, 4, 5},
            {1, 2, 3, 4},
        };
    };
    Grid g1 = mk(), g2 = mk();
    std::vector<std::vector<int>> i1(4, std::vector<int>(4, 0)); i1[0][2] = 1;
    std::vector<std::vector<int>> i2(4, std::vector<int>(4, 0)); i2[0][2] = 1;
    std::mt19937 r1(24680), r2(24680);
    auto a = resolve_ingredient(g1, {0, 1, 2, 3, 4, 5}, r1, nullptr, nullptr, nullptr, &i1, {0, 1, 2, 3}, nullptr, true);
    auto b = resolve_ingredient(g2, {0, 1, 2, 3, 4, 5}, r2, nullptr, nullptr, nullptr, &i2, {0, 1, 2, 3}, nullptr, true);
    CHECK(g1 == g2, "same seed -> identical grid after resolve");
    CHECK(i1 == i2, "same seed -> identical ing layer after resolve");
    CHECK_EQ(a.ingredient_collected, b.ingredient_collected, "same seed -> identical collected count");
}

// ───────────── 倒计时炸弹（Bomb）镜像断言 ─────────────

static void test_bomb_cell_still_matches() {
    // 炸弹格的 grid 是普通棋子 → 照常参与匹配（炸弹不感知于 find_matches，故不断串）。
    Grid g = {{0, 0, 0, 1}, {2, 3, 4, 2}, {3, 4, 2, 3}};
    // bomb 层存在与否都不影响 find_matches（无 *_bomb 的匹配版本：炸弹格当普通棋子）。
    CHECK_EQ((int)find_matches(g).size(), 3, "bomb cell does NOT break the run (bomb tile is a normal piece)");
}

static void test_bomb_falls_under_gravity() {
    // 炸弹随重力下落：bomb 作为纯标记随 grid 搬运（与 ingredient 同构）。列 [炸弹,空,空] → 沉到列底。
    Grid col = {{5}, {EMPTY}, {EMPTY}};
    std::vector<std::vector<int>> bomb = {{3}, {0}, {0}};
    apply_gravity_bomb(col, nullptr, nullptr, &bomb);
    CHECK_EQ(col[2][0], 5, "bomb tile fell to the column bottom");
    CHECK_EQ(bomb[2][0], 3, "bomb countdown moved with the tile (now at bottom)");
    CHECK_EQ(col[0][0], EMPTY, "top is now empty");
    CHECK_EQ(bomb[0][0], 0, "bomb layer cleared at the old top cell");
}

static void test_tick_bombs_decrements_and_explodes() {
    // 每步递减：所有 bomb>0 -1；归零数 = 引爆数。
    std::vector<std::vector<int>> bomb = {{3, 0, 5}, {0, 2, 0}, {1, 0, 4}};
    int exploded = tick_bombs(bomb);
    CHECK_EQ(bomb[0][0], 2, "bomb -1");
    CHECK_EQ(bomb[1][1], 1, "bomb -1");
    CHECK_EQ(bomb[2][0], 0, "bomb 1 -> 0 (explodes)");
    CHECK_EQ(bomb[2][2], 3, "bomb -1");
    CHECK_EQ(exploded, 1, "exactly one bomb reached 0");
    CHECK_EQ(count_bombs(bomb), 4, "four bombs still live after the tick");
}

static void test_resolve_bomb_defused_when_matched() {
    // 炸弹格本身在三连里 → 被消除拆弹（bomb→0），bomb_defused 计数。
    Grid g = {{0, 0, 0, 1}, {2, 3, 4, 2}, {3, 4, 2, 3}};
    std::vector<std::vector<int>> bomb(3, std::vector<int>(4, 0));
    bomb[0][1] = 4;  // 炸弹在第0行三连里
    std::mt19937 rng(1);
    auto r = resolve_bomb(g, {0, 1, 2, 3, 4}, rng, nullptr, nullptr, &bomb, nullptr, false);
    CHECK_EQ(r.bomb_defused, 1, "bomb in the match got defused");
    CHECK_EQ(count_bombs(bomb), 0, "no bombs remain (defused)");
}

static void test_resolve_bomb_sinks_one_after_clear() {
    // 炸弹格正下方棋子被消除 → 炸弹格(普通棋子)随重力下沉一格，bomb 标记跟随，本格未被消除→不拆。
    Grid g = {
        {0, 1, 2, 3},
        {4, 8, 6, 0},   // (1,1)=8 盖炸弹
        {7, 7, 7, 1},   // 第2行三连
        {2, 3, 4, 5},
    };
    std::vector<std::vector<int>> bomb(4, std::vector<int>(4, 0));
    bomb[1][1] = 5;
    std::mt19937 rng(1);
    auto r = resolve_bomb(g, {0, 1, 2, 3, 4, 5, 6, 7, 8}, rng, nullptr, nullptr, &bomb, nullptr, false);
    CHECK_EQ(bomb[2][1], 5, "bomb countdown sank exactly one row (y=1 -> y=2)");
    CHECK_EQ(g[2][1], 8, "bomb-covered tile moved down with it (species 8 preserved)");
    CHECK_EQ(bomb[1][1], 0, "old bomb cell cleared");
    CHECK_EQ(r.bomb_defused, 0, "tile below cleared, bomb tile itself NOT cleared -> not defused");
}

static void test_resolve_bomb_deterministic() {
    // 同 seed 两次完整 resolve（含下落+补充）结果一致。
    auto mk = []() {
        return Grid{
            {0, 1, 8, 3},
            {4, 5, 0, 1},
            {2, 3, 4, 5},
            {1, 2, 3, 4},
        };
    };
    Grid g1 = mk(), g2 = mk();
    std::vector<std::vector<int>> b1(4, std::vector<int>(4, 0)); b1[0][2] = 4;
    std::vector<std::vector<int>> b2(4, std::vector<int>(4, 0)); b2[0][2] = 4;
    std::mt19937 r1(13579), r2(13579);
    auto a = resolve_bomb(g1, {0, 1, 2, 3, 4, 5}, r1, nullptr, nullptr, &b1, nullptr, true);
    auto b = resolve_bomb(g2, {0, 1, 2, 3, 4, 5}, r2, nullptr, nullptr, &b2, nullptr, true);
    CHECK(g1 == g2, "same seed -> identical grid after resolve");
    CHECK(b1 == b2, "same seed -> identical bomb layer after resolve");
    CHECK_EQ(a.bomb_defused, b.bomb_defused, "same seed -> identical bomb_defused");
}

// ───────────── 糖果炮（Candy Cannon）镜像断言 ─────────────

static void test_cannon_spawns_below_when_empty() {
    // 炮口格(WALL)正下方空 → 产一个棋子(species 来自 species_set)。炮在 (1,0)，其下 (1,1) 空。
    Grid g = {{WALL, WALL, WALL}, {0, EMPTY, 2}, {1, 2, 3}};
    std::vector<std::vector<int>> cannon(3, std::vector<int>(3, 0));
    cannon[0][1] = 1;  // 产普通糖炮
    std::mt19937 rng(1);
    int produced = spawn_from_cannons(cannon, g, {0, 1, 2, 3, 4}, rng);
    CHECK_EQ(produced, 1, "one cannon produced one piece below it");
    CHECK(g[1][1] != EMPTY && g[1][1] != WALL, "below-cannon cell now holds a normal piece");
}

static void test_cannon_type2_produces_ingredient() {
    // cannon=2 → 产原料：产出格 grid 是普通棋子且 ing=1（与运料关协同）。
    Grid g = {{WALL, 1, 2}, {EMPTY, 3, 4}, {5, 0, 1}};
    std::vector<std::vector<int>> cannon(3, std::vector<int>(3, 0));
    cannon[0][0] = 2;  // 产原料炮在 (0,0)，其下 (0,1) 空
    std::vector<std::vector<int>> ing(3, std::vector<int>(3, 0));
    std::mt19937 rng(7);
    int produced = spawn_from_cannons(cannon, g, {0, 1, 2, 3, 4, 5}, rng, &ing);
    CHECK_EQ(produced, 1, "ingredient cannon produced one piece");
    CHECK(g[1][0] != EMPTY && g[1][0] != WALL, "produced cell holds a normal-species tile");
    CHECK_EQ(ing[1][0], 1, "produced cell is marked as an ingredient (ing=1)");
}

static void test_cannon_no_spawn_when_below_occupied() {
    // 炮口正下方非空 → 本步不产（等位置空出）。
    Grid g = {{WALL, 1, 2}, {9, 3, 4}, {5, 0, 1}};  // (0,1)=9 非空
    std::vector<std::vector<int>> cannon(3, std::vector<int>(3, 0));
    cannon[0][0] = 1;
    std::mt19937 rng(1);
    int produced = spawn_from_cannons(cannon, g, {0, 1, 2, 3, 4}, rng);
    CHECK_EQ(produced, 0, "below occupied -> cannon does not produce this step");
    CHECK_EQ(g[1][0], 9, "occupied cell below cannon is untouched");
}

static void test_cannon_no_spawn_at_bottom_row() {
    // 炮口在最底行 → 下方无格可产，不产。
    Grid g = {{0, 1, 2}, {3, 4, 5}, {WALL, 1, 2}};
    std::vector<std::vector<int>> cannon(3, std::vector<int>(3, 0));
    cannon[2][0] = 1;  // 最底行的炮
    std::mt19937 rng(1);
    int produced = spawn_from_cannons(cannon, g, {0, 1, 2, 3, 4}, rng);
    CHECK_EQ(produced, 0, "cannon at bottom row has no cell below -> no spawn");
}

static void test_count_cannons() {
    std::vector<std::vector<int>> cannon = {{1, 0, 2}, {0, 0, 0}, {0, 1, 0}};
    CHECK_EQ(count_cannons(cannon), 3, "three cannon cells counted");
}

static void test_cannon_deterministic_same_seed() {
    // 同 seed 两次产出 → 盘面一致。
    auto mk = []() { return Grid{{WALL, WALL, WALL}, {EMPTY, EMPTY, EMPTY}, {0, 1, 2}}; };
    Grid g1 = mk(), g2 = mk();
    std::vector<std::vector<int>> c1(3, std::vector<int>(3, 0));
    c1[0][0] = 1; c1[0][1] = 1; c1[0][2] = 1;
    auto c2 = c1;
    std::mt19937 r1(2468), r2(2468);
    int p1 = spawn_from_cannons(c1, g1, {0, 1, 2, 3, 4, 5}, r1);
    int p2 = spawn_from_cannons(c2, g2, {0, 1, 2, 3, 4, 5}, r2);
    CHECK_EQ(p1, p2, "same seed -> identical produced count");
    CHECK(g1 == g2, "same seed -> identical grid after cannon spawn");
}

// ───────────── 爆米花（Popcorn）镜像断言 ─────────────

static void test_popcorn_not_matched() {
    // 爆米花格(popcorn>0)不参与匹配、断开同色串（镜像 GDScript test_popcorn_not_matched）。
    Grid g = {{0, 0, 0, 1}, {2, 3, 4, 2}, {3, 4, 2, 3}};
    CHECK_EQ((int)find_matches_popcorn(g, nullptr, nullptr, nullptr, nullptr).size(), 3, "no popcorn -> top row is a 3-match");
    std::vector<std::vector<int>> pop(3, std::vector<int>(4, 0));
    pop[0][1] = 2;  // 中间格爆米花
    CHECK(find_matches_popcorn(g, nullptr, nullptr, nullptr, &pop).empty(), "popcorn cell breaks the run -> no match");
}

static void test_popcorn_blocks_swap() {
    // 爆米花格不可交换；无 popcorn 指针时退化为正常合法。
    Grid g = {{5, 5, 0, 5}, {1, 2, 3, 4}, {2, 3, 4, 1}};
    std::vector<std::vector<int>> pop(3, std::vector<int>(4, 0));
    pop[0][2] = 1;  // (2,0) 是爆米花
    CHECK(!is_legal_swap_popcorn(g, {2, 0}, {3, 0}, nullptr, nullptr, nullptr, &pop), "popcorn cell can't be swapped");
    CHECK(is_legal_swap_popcorn(g, {2, 0}, {3, 0}, nullptr, nullptr, nullptr, nullptr), "no popcorn ptr -> normal legal swap");
}

static void test_popcorn_falls_under_gravity() {
    // 爆米花随重力下落：popcorn 作为标记随 grid 搬运（与 ingredient/bomb 同构）。列 [爆米花,空,空] → 沉到列底。
    Grid col = {{5}, {EMPTY}, {EMPTY}};
    std::vector<std::vector<int>> pop = {{2}, {0}, {0}};
    apply_gravity_popcorn(col, nullptr, nullptr, &pop);
    CHECK_EQ(col[2][0], 5, "popcorn tile fell to the column bottom");
    CHECK_EQ(pop[2][0], 2, "popcorn count moved with the tile (now at bottom)");
    CHECK_EQ(col[0][0], EMPTY, "top is now empty");
    CHECK_EQ(pop[0][0], 0, "popcorn layer cleared at the old top cell");
}

static void test_popcorn_sinks_when_tile_below_cleared() {
    // 爆米花格正下方棋子被消除 → 爆米花格(占位棋子)随重力下沉一格，popcorn 标记跟随。
    // 用 apply_gravity_popcorn 直接验证（C++ 裸 Core 不跑特效 resolve，但重力跟随机械原语须一致）。
    // 列0: [占位8, 空, 7] —— 下方 (0,1) 空 → 爆米花占位 8 沉一格到 (0,1)，popcorn 跟随。
    Grid col = {{8}, {EMPTY}, {7}};
    std::vector<std::vector<int>> pop = {{3}, {0}, {0}};
    apply_gravity_popcorn(col, nullptr, nullptr, &pop);
    CHECK_EQ(col[1][0], 8, "popcorn-covered tile sank exactly one row (y=0 -> y=1)");
    CHECK_EQ(pop[1][0], 3, "popcorn count followed the tile down");
    CHECK_EQ(pop[0][0], 0, "old popcorn cell cleared");
    CHECK_EQ(col[2][0], 7, "the tile below (7) stayed put at the bottom");
}

static void test_hit_popcorn_decrements_on_cleared_set() {
    // 特效命中（格在清除集）→ popcorn-1；不在清除集的爆米花不变。镜像 GDScript _hit_popcorn 的递减部分。
    std::vector<std::vector<int>> pop = {{2, 0, 1}, {0, 3, 0}, {0, 0, 1}};
    // 清除集波及 (0,0) 与 (1,1)（两格爆米花），不波及 (2,0)/(2,2)。
    std::vector<Vec2> cleared = {{0, 0}, {1, 1}, {2, 1}};  // (2,1)=普通格(popcorn=0)不计
    int hits = hit_popcorn(pop, cleared);
    CHECK_EQ(hits, 2, "two popcorn cells in the cleared set were hit");
    CHECK_EQ(pop[0][0], 1, "popcorn (0,0) decremented 2 -> 1");
    CHECK_EQ(pop[1][1], 2, "popcorn (1,1) decremented 3 -> 2");
    CHECK_EQ(pop[0][2], 1, "popcorn (2,0) untouched (not in cleared set)");
    CHECK_EQ(pop[2][2], 1, "popcorn (2,2) untouched (not in cleared set)");
}

static void test_hit_popcorn_only_self_not_adjacent() {
    // 关键区别于巧克力：只认"格自身在清除集"，正交相邻【不】命中。
    std::vector<std::vector<int>> pop(3, std::vector<int>(3, 0));
    pop[1][1] = 2;  // 中心爆米花
    std::vector<Vec2> adjacent_only = {{0, 1}, {2, 1}, {1, 0}, {1, 2}};  // 四个正交相邻，均不含中心
    int hits = hit_popcorn(pop, adjacent_only);
    CHECK_EQ(hits, 0, "adjacency does NOT hit popcorn (only the cell itself counts)");
    CHECK_EQ(pop[1][1], 2, "center popcorn unchanged by adjacent clears");
}

static void test_hit_popcorn_to_zero() {
    // popcorn=1 被命中 → 归0（C++ 裸 Core 不在此变彩球，只递减到 0）。
    std::vector<std::vector<int>> pop(2, std::vector<int>(2, 0));
    pop[0][0] = 1;
    int hits = hit_popcorn(pop, {{0, 0}});
    CHECK_EQ(hits, 1, "the single-hit popcorn was hit");
    CHECK_EQ(pop[0][0], 0, "popcorn reached 0 (Godot side converts to color bomb; C++ leaves it at 0)");
    CHECK_EQ(count_popcorn(pop), 0, "no popcorn remains after reaching 0");
}

static void test_count_popcorn() {
    std::vector<std::vector<int>> pop = {{2, 0, 1}, {0, 0, 0}, {0, 3, 0}};
    CHECK_EQ(count_popcorn(pop), 3, "three popcorn cells counted");
}

static void test_popcorn_deterministic_gravity() {
    // 同输入两次重力下落 → 盘面/popcorn 层一致（确定性；apply_gravity_popcorn 纯函数无 rng）。
    auto mkg = []() { return Grid{{8, 1}, {EMPTY, 2}, {EMPTY, 3}}; };
    auto mkp = []() { return std::vector<std::vector<int>>{{2, 0}, {0, 0}, {0, 0}}; };
    Grid g1 = mkg(), g2 = mkg();
    auto p1 = mkp(), p2 = mkp();
    apply_gravity_popcorn(g1, nullptr, nullptr, &p1);
    apply_gravity_popcorn(g2, nullptr, nullptr, &p2);
    CHECK(g1 == g2, "same input -> identical grid after popcorn gravity");
    CHECK(p1 == p2, "same input -> identical popcorn layer after gravity");
}

// ───────────── 蛋糕炸弹（Cake Bomb）镜像断言 ─────────────

static void test_cake_cell_is_wall_not_matchable() {
    // 蛋糕格 grid=WALL → 永不进 find_matches（镜像 GDScript test_cake_cell_is_wall_not_matchable）。
    Grid g = {{WALL, 0, 0, 0}, {1, 2, 3, 4}, {2, 3, 4, 1}};
    auto m = find_matches(g);
    CHECK_EQ((int)m.size(), 3, "WALL cake cell never matches; the three 0s still form a run");
    for (const auto& p : m) CHECK(g[p.y][p.x] != WALL, "no WALL cake cell in a match set");
}

static void test_cake_cell_is_wall_not_swappable() {
    // 蛋糕格 grid=WALL → is_legal_swap 拒绝（墙不可动）。
    Grid g = {{WALL, 0, 1, 2}, {0, 3, 4, 5}, {2, 3, 4, 1}};
    CHECK(!is_legal_swap(g, {0, 0}, {1, 0}), "WALL cake cell cannot be swapped");
}

static void test_cake_cell_does_not_fall() {
    // 蛋糕格 grid=WALL → apply_gravity 处切段、原地固定（墙不下落）。
    Grid g = {{WALL}, {5}, {EMPTY}};
    apply_gravity(g);
    CHECK_EQ(g[0][0], WALL, "WALL cake cell stays put (does not fall)");
    CHECK_EQ(g[2][0], 5, "piece below the cake sank to the segment bottom");
    CHECK_EQ(g[1][0], EMPTY, "cell vacated by the sunk piece is now empty");
}

static void test_square_cells_3x3_geometry() {
    // square_cells r=1 = 以 center 为心 3x3 的非 WALL/非 EMPTY 普通格（中心是蛋糕墙不计、空格不计）。
    Grid g = {
        {0, 1, 2, 3, 4},
        {5, 6, 7, 8, 0},
        {1, 2, WALL, 3, 4},   // (2,2)=蛋糕墙
        {5, 6, 7, 8, 0},
        {1, 2, 3, 4, 5},
    };
    auto cells = square_cells(g, {2, 2}, 1);
    // 3x3 共9格，去掉中心蛋糕墙(1格) → 8 个普通格。
    CHECK_EQ((int)cells.size(), 8, "3x3 ring minus the WALL center = 8 normal cells");
    bool has_center = false, out_of_ring = false;
    for (const auto& c : cells) {
        if (c.x == 2 && c.y == 2) has_center = true;
        if (c.x < 1 || c.x > 3 || c.y < 1 || c.y > 3) out_of_ring = true;
    }
    CHECK(!has_center, "the WALL cake center is not in the ring");
    CHECK(!out_of_ring, "all ring cells are within x in [1,3], y in [1,3]");
}

static void test_square_cells_5x5_big_blast() {
    // square_cells r=2 = 5x5 大爆炸几何（归0时用）。蛋糕在 (2,2)，5x5 覆盖整 5x5 盘减去中心墙。
    Grid g = {
        {0, 1, 2, 3, 4},
        {5, 6, 7, 8, 0},
        {1, 2, WALL, 3, 4},
        {5, 6, 7, 8, 0},
        {1, 2, 3, 4, 5},
    };
    auto cells = square_cells(g, {2, 2}, CAKE_BLAST_RADIUS);
    CHECK_EQ((int)cells.size(), 24, "5x5 big blast minus the WALL center = 24 normal cells");
    bool has_corner_00 = false, has_corner_44 = false;
    for (const auto& c : cells) {
        if (c.x == 0 && c.y == 0) has_corner_00 = true;
        if (c.x == 4 && c.y == 4) has_corner_44 = true;
    }
    CHECK(has_corner_00, "5x5 big blast reaches corner (0,0)");
    CHECK(has_corner_44, "5x5 big blast reaches corner (4,4)");
}

static void test_blast_cakes_decrements_and_blasts_ring() {
    // 相邻被清的蛋糕 cake-1 + 引爆 3x3。蛋糕在 (2,2) 血量 3，清除集含其邻格 (2,1) → -1(→2,存活) + 3x3 引爆。
    Grid g = {
        {0, 1, 2, 3, 4},
        {5, 6, 7, 8, 0},
        {1, 2, WALL, 3, 4},
        {5, 6, 7, 8, 0},
        {1, 2, 3, 4, 5},
    };
    std::vector<std::vector<int>> cake(5, std::vector<int>(5, 0));
    cake[2][2] = 3;
    std::vector<Vec2> blast;
    int destroyed = blast_cakes(g, cake, {{2, 1}}, &blast);
    CHECK_EQ(destroyed, 0, "cake alive (HP 2) -> not destroyed");
    CHECK_EQ(cake[2][2], 2, "cake adjacent to a cleared cell lost exactly 1 HP (3 -> 2)");
    CHECK_EQ(g[2][2], WALL, "alive cake stays a WALL (not removed)");
    // 3x3 引爆集含四角（(1,1)(3,1)(1,3)(3,3)），不含中心蛋糕墙。
    bool c11 = false, c33 = false, center = false;
    for (const auto& b : blast) {
        if (b.x == 1 && b.y == 1) c11 = true;
        if (b.x == 3 && b.y == 3) c33 = true;
        if (b.x == 2 && b.y == 2) center = true;
    }
    CHECK(c11 && c33, "3x3 ring blast includes the corners");
    CHECK(!center, "the cake WALL cell itself is not in the blast set");
}

static void test_blast_cakes_zero_removes_and_big_blast() {
    // 血量 1 的蛋糕相邻被清 → 归0 → 移除(WALL→EMPTY) + 5x5 大爆炸。
    Grid g = {
        {0, 1, 2, 3, 4},
        {5, 6, 7, 8, 0},
        {1, 2, WALL, 3, 4},
        {5, 6, 7, 8, 0},
        {1, 2, 3, 4, 5},
    };
    std::vector<std::vector<int>> cake(5, std::vector<int>(5, 0));
    cake[2][2] = 1;
    std::vector<Vec2> blast;
    int destroyed = blast_cakes(g, cake, {{2, 3}}, &blast);
    CHECK_EQ(destroyed, 1, "exactly one cake destroyed (HP reached 0)");
    CHECK_EQ(cake[2][2], 0, "destroyed cake HP is 0");
    CHECK_EQ(g[2][2], EMPTY, "destroyed cake removed: WALL -> EMPTY");
    bool corner00 = false, corner44 = false;
    for (const auto& b : blast) {
        if (b.x == 0 && b.y == 0) corner00 = true;
        if (b.x == 4 && b.y == 4) corner44 = true;
    }
    CHECK(corner00 && corner44, "5x5 big blast reaches the far corners on destroy");
}

static void test_blast_cakes_max_one_per_round() {
    // 每轮最多-1：蛋糕同时正交相邻多个被清格(上下左右)，本轮也只 -1。
    Grid g = {
        {0, 1, 2, 3, 4},
        {5, 6, 9, 8, 0},
        {7, 9, WALL, 9, 4},   // (2,1)(2,3)? 这里给四邻全普通格
        {5, 6, 9, 8, 0},
        {1, 2, 3, 4, 5},
    };
    std::vector<std::vector<int>> cake(5, std::vector<int>(5, 0));
    cake[2][2] = 5;
    // 清除集 = 蛋糕四个正交邻格。
    int destroyed = blast_cakes(g, cake, {{2, 1}, {2, 3}, {1, 2}, {3, 2}}, nullptr);
    CHECK_EQ(destroyed, 0, "cake not destroyed (still has HP)");
    CHECK_EQ(cake[2][2], 4, "cake adjacent to 4 cleared cells in one round loses only 1 HP (5 -> 4)");
}

static void test_blast_cakes_no_adjacency_no_change() {
    // 蛋糕周围无被清格 → 不掉血、不引爆（blast 为空）。
    Grid g = {
        {0, 1, 2},
        {3, WALL, 4},
        {5, 6, 7},
    };
    std::vector<std::vector<int>> cake(3, std::vector<int>(3, 0));
    cake[1][1] = 2;
    std::vector<Vec2> blast;
    // 清除集是远离蛋糕的角 (0,0)（与 (1,1) 不正交相邻）。
    int destroyed = blast_cakes(g, cake, {{0, 0}}, &blast);
    CHECK_EQ(destroyed, 0, "no adjacency -> no cake destroyed");
    CHECK_EQ(cake[1][1], 2, "no adjacency -> cake HP unchanged");
    CHECK(blast.empty(), "no adjacency -> no blast cells");
}

static void test_count_cakes() {
    std::vector<std::vector<int>> cake = {{3, 0, 1}, {0, 0, 0}, {0, 2, 0}};
    CHECK_EQ(count_cakes(cake), 3, "three cake cells counted");
}

static void test_cake_deterministic_geometry() {
    // 同输入两次 blast → 盘面/cake 层/destroyed 一致（纯几何无 rng）。
    auto mkg = []() { return Grid{{0, 1, 2}, {3, WALL, 4}, {5, 6, 7}}; };
    auto mkc = []() { return std::vector<std::vector<int>>{{0, 0, 0}, {0, 1, 0}, {0, 0, 0}}; };
    Grid g1 = mkg(), g2 = mkg();
    auto c1 = mkc(), c2 = mkc();
    std::vector<Vec2> b1, b2;
    int d1 = blast_cakes(g1, c1, {{1, 0}}, &b1);
    int d2 = blast_cakes(g2, c2, {{1, 0}}, &b2);
    CHECK_EQ(d1, d2, "same input -> identical destroyed count");
    CHECK(g1 == g2, "same input -> identical grid after cake blast");
    CHECK(c1 == c2, "same input -> identical cake layer after blast");
    CHECK(b1 == b2, "same input -> identical blast cells");
}

// ───────────── 神秘糖（Mystery Candy）镜像断言 ─────────────

static void test_mystery_cell_still_matches() {
    // 神秘糖格 grid=普通 species → 正常进 find_matches（神秘糖不感知于匹配，当普通棋子参与）。
    // 三个 0 横向三连，其中 (1,0) 设为神秘糖也不影响——find_matches 不接 mystery 参数。
    Grid g = {{0, 0, 0, 1}, {1, 2, 3, 2}, {2, 3, 1, 0}};
    auto m = find_matches(g);
    CHECK_EQ((int)m.size(), 3, "mystery cell (grid=normal species) participates in matching like a normal candy");
}

static void test_mystery_falls_under_gravity() {
    // 神秘糖格 grid 是普通棋子 → 随重力下落；mystery 标记跟随（apply_gravity_mystery）。
    // (0,0)=神秘糖(grid=5)，下方两格空 → 沉到列底 (2,0)，标记也从 (0,0) 移到 (2,0)。
    Grid g = {{5}, {EMPTY}, {EMPTY}};
    std::vector<std::vector<int>> mystery = {{1}, {0}, {0}};
    apply_gravity_mystery(g, nullptr, nullptr, &mystery);
    CHECK_EQ(g[2][0], 5, "mystery candy (normal piece) sank to the column bottom");
    CHECK_EQ(g[0][0], EMPTY, "top cell vacated after the mystery candy fell");
    CHECK_EQ(mystery[2][0], 1, "mystery marker followed its candy down to (2,0)");
    CHECK_EQ(mystery[0][0], 0, "mystery marker no longer at the old top position");
}

static void test_mystery_marker_follows_after_clear_below() {
    // 下方格被清空后，神秘糖随重力下沉，标记跟随（与 GDScript test_mystery_marker_follows_after_clear_below 一致）。
    Grid g = {{9}, {EMPTY}, {EMPTY}, {EMPTY}};
    std::vector<std::vector<int>> mystery = {{1}, {0}, {0}, {0}};
    apply_gravity_mystery(g, nullptr, nullptr, &mystery);
    CHECK_EQ(g[3][0], 9, "mystery candy fell to the bottom after the cells below were cleared");
    CHECK_EQ(mystery[3][0], 1, "mystery marker followed the candy down to the bottom");
    CHECK_EQ(count_mystery(mystery), 1, "still exactly one mystery candy on board (only moved, not consumed)");
}

static void test_reveal_mystery_clears_flag() {
    // 揭开必清 mystery 标记（无论掷到哪档），且 grid 落普通 species（>=0）。
    Grid g = {{3}};
    std::vector<std::vector<int>> ing = {{0}};
    std::vector<std::vector<int>> mystery = {{1}};
    std::mt19937 rng(7);
    std::vector<int> species = {0, 1, 2, 3, 4, 5};
    reveal_mystery_at(g, &ing, mystery, {0, 0}, rng, species);
    CHECK_EQ(mystery[0][0], 0, "reveal always clears the mystery flag");
    CHECK(g[0][0] >= 0, "revealed mystery cell holds new content (grid >= 0), not EMPTY");
}

static void test_reveal_mystery_buckets() {
    // 概率分配(70/20/10)覆盖三档：多次揭开应同时出现 普通糖(bucket 0)/特效档(bucket 1)/原料(bucket 2)。
    // 用累计标志在循环外断言（避免循环内 CHECK 膨胀断言计数）。
    std::mt19937 rng(2024);
    std::vector<int> species = {0, 1, 2, 3, 4, 5};
    bool b0 = false, b1 = false, b2 = false;
    bool flag_always_cleared = true;   // 每次揭开都清了 mystery 标记
    bool ing_set_on_bucket2 = true;    // bucket 2 都置了 ing=1
    for (int i = 0; i < 400; ++i) {
        Grid g = {{3}};
        std::vector<std::vector<int>> ing = {{0}};
        std::vector<std::vector<int>> mystery = {{1}};
        int bucket = reveal_mystery_at(g, &ing, mystery, {0, 0}, rng, species);
        if (mystery[0][0] != 0) flag_always_cleared = false;
        if (bucket == 0) b0 = true;
        else if (bucket == 1) b1 = true;
        else if (bucket == 2) { b2 = true; if (ing[0][0] != 1) ing_set_on_bucket2 = false; }
    }
    CHECK(flag_always_cleared, "reveal clears the mystery flag every time");
    CHECK(ing_set_on_bucket2, "ingredient bucket sets ing=1 every time");
    CHECK(b0, "70% bucket hit: plain species reveals occur");
    CHECK(b1, "20% bucket hit: effect-bucket reveals occur (degrade to plain in C++)");
    CHECK(b2, "10% bucket hit: ingredient reveals occur");
}

static void test_reveal_mystery_deterministic() {
    // 同 seed 同输入两次揭开 → grid/ing/mystery/bucket 完全一致（确定性）。
    auto mkg = []() { return Grid{{3}}; };
    Grid g1 = mkg(), g2 = mkg();
    std::vector<std::vector<int>> i1 = {{0}}, i2 = {{0}};
    std::vector<std::vector<int>> m1 = {{1}}, m2 = {{1}};
    std::mt19937 r1(13579), r2(13579);
    std::vector<int> species = {0, 1, 2, 3, 4};
    int b1 = reveal_mystery_at(g1, &i1, m1, {0, 0}, r1, species);
    int b2 = reveal_mystery_at(g2, &i2, m2, {0, 0}, r2, species);
    CHECK_EQ(b1, b2, "same seed -> identical reveal bucket");
    CHECK(g1 == g2, "same seed -> identical grid after reveal");
    CHECK(i1 == i2, "same seed -> identical ing after reveal");
    CHECK(m1 == m2, "same seed -> identical mystery after reveal");
}

static void test_count_mystery() {
    std::vector<std::vector<int>> mystery = {{1, 0, 1}, {0, 0, 0}, {0, 1, 0}};
    CHECK_EQ(count_mystery(mystery), 3, "three mystery candies counted");
}

static void test_mystery_deterministic_gravity() {
    // 同输入两次重力下落 → 盘面/mystery 层一致（apply_gravity_mystery 纯函数无 rng）。
    auto mkg = []() { return Grid{{8, 1}, {EMPTY, 2}, {EMPTY, 3}}; };
    auto mkm = []() { return std::vector<std::vector<int>>{{1, 0}, {0, 0}, {0, 0}}; };
    Grid g1 = mkg(), g2 = mkg();
    auto m1 = mkm(), m2 = mkm();
    apply_gravity_mystery(g1, nullptr, nullptr, &m1);
    apply_gravity_mystery(g2, nullptr, nullptr, &m2);
    CHECK(g1 == g2, "same input -> identical grid after mystery gravity");
    CHECK(m1 == m2, "same input -> identical mystery layer after gravity");
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
    test_refill_from_feed();
    test_score_escalates();
    test_legal_swap();
    test_has_legal_move();
    test_resolve();
    test_resolve_deterministic();
    test_make_board();
    test_reshuffle_keeps_walls();
    test_reshuffle_coat_aware();
    // 巧克力蔓延（Chocolate）镜像断言
    test_choco_not_matched();
    test_choco_blocks_swap();
    test_choco_blocks_gravity();
    test_eat_chocolate_direct();
    test_resolve_choco_eaten_by_adjacency();
    test_spread_adds_one();
    test_spread_no_candidate();
    test_spread_deterministic();
    test_resolve_choco_no_eat_far_clear();
    // 运原料（Ingredients）镜像断言
    test_ingredient_not_matched();
    test_ingredient_blocks_swap();
    test_ingredient_falls_under_gravity();
    test_collect_at_exit_direct();
    test_collect_respects_exit_cols();
    test_resolve_ingredient_sinks_to_bottom();
    test_resolve_ingredient_sinks_one_after_clear();
    test_resolve_ingredient_deterministic();
    // 倒计时炸弹（Bomb）镜像断言
    test_bomb_cell_still_matches();
    test_bomb_falls_under_gravity();
    test_tick_bombs_decrements_and_explodes();
    test_resolve_bomb_defused_when_matched();
    test_resolve_bomb_sinks_one_after_clear();
    test_resolve_bomb_deterministic();
    // 糖果炮（Candy Cannon）镜像断言
    test_cannon_spawns_below_when_empty();
    test_cannon_type2_produces_ingredient();
    test_cannon_no_spawn_when_below_occupied();
    test_cannon_no_spawn_at_bottom_row();
    test_count_cannons();
    test_cannon_deterministic_same_seed();
    // 爆米花（Popcorn）镜像断言
    test_popcorn_not_matched();
    test_popcorn_blocks_swap();
    test_popcorn_falls_under_gravity();
    test_popcorn_sinks_when_tile_below_cleared();
    test_hit_popcorn_decrements_on_cleared_set();
    test_hit_popcorn_only_self_not_adjacent();
    test_hit_popcorn_to_zero();
    test_count_popcorn();
    test_popcorn_deterministic_gravity();
    // 蛋糕炸弹（Cake Bomb）镜像断言
    test_cake_cell_is_wall_not_matchable();
    test_cake_cell_is_wall_not_swappable();
    test_cake_cell_does_not_fall();
    test_square_cells_3x3_geometry();
    test_square_cells_5x5_big_blast();
    test_blast_cakes_decrements_and_blasts_ring();
    test_blast_cakes_zero_removes_and_big_blast();
    test_blast_cakes_max_one_per_round();
    test_blast_cakes_no_adjacency_no_change();
    test_count_cakes();
    test_cake_deterministic_geometry();
    // 神秘糖（Mystery Candy）镜像断言
    test_mystery_cell_still_matches();
    test_mystery_falls_under_gravity();
    test_mystery_marker_follows_after_clear_below();
    test_reveal_mystery_clears_flag();
    test_reveal_mystery_buckets();
    test_reveal_mystery_deterministic();
    test_count_mystery();
    test_mystery_deterministic_gravity();
    return report();
}
