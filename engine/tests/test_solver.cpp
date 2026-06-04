// 求解器单测。
#include "check.hpp"
#include "../include/solver.hpp"

using namespace me;

static Level make_level(int target, int moves, uint32_t board_seed, uint32_t play_seed) {
    std::mt19937 gen(board_seed);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.target_score = target;
    lv.move_limit = moves;
    lv.seed = play_seed;
    return lv;
}

static void test_move_value() {
    ResolveResult rr;
    rr.score = 50;
    rr.jelly_cleared = 3;
    rr.blocker_cleared = 2;
    rr.by_species = {1, 4};  // species0:1, species1:4
    Level sc;  // 无目标 → 纯分数
    CHECK_EQ((int)move_value(rr, sc), 50, "no objective -> score");
    Level col;
    col.objectives = {{OBJ_COLLECT, 1, 10}};
    CHECK((int)move_value(rr, col) >= 400, "COLLECT weights target species (4*100)");
    Level jel;
    jel.objectives = {{OBJ_CLEAR_JELLY, -1, 10}};
    CHECK((int)move_value(rr, jel) >= 300, "JELLY weights jelly_cleared (3*100)");
    Level blk;
    blk.objectives = {{OBJ_CLEAR_BLOCKER, -1, 10}};
    CHECK((int)move_value(rr, blk) >= 200, "BLOCKER weights blocker_cleared (2*100)");
}

static void test_smart_greedy_pursues_collect() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.move_limit = 15;
    lv.seed = 7;
    lv.objectives = {{OBJ_COLLECT, 0, 9999}};  // 不可能 → 走满步、最大化收集 species 0
    auto smart = smart_greedy_play(lv);
    auto dumb = greedy_play(lv);  // 只刷分
    int s0_smart = !smart.collected.empty() ? smart.collected[0] : 0;
    int s0_dumb = !dumb.collected.empty() ? dumb.collected[0] : 0;
    CHECK(s0_smart >= s0_dumb, "objective-aware collects >= score-greedy of the target species");
}

static void test_smart_greedy_pursues_jelly() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.jelly.assign(8, std::vector<int>(8, 0));
    for (int i = 0; i < 8; ++i) lv.jelly[i][i] = 1;  // 稀疏对角果冻
    lv.move_limit = 15;
    lv.seed = 7;
    lv.objectives = {{OBJ_CLEAR_JELLY, -1, 9999}};  // 不可能 → 最大化清果冻
    auto smart = smart_greedy_play(lv);
    auto dumb = greedy_play(lv);
    CHECK(smart.jelly_cleared >= dumb.jelly_cleared, "objective-aware clears >= jelly than score-greedy");
}

static void test_greedy_plays_out_impossible_target() {
    Level lv = make_level(100000, 30, 123, 777);  // 不可能的目标 → 走满步
    auto r = greedy_play(lv);
    CHECK(!r.won, "impossible target -> not won");
    CHECK_EQ(r.moves_used, 30, "plays all moves");
    CHECK(r.score > 0, "greedy actually scores");
}

static void test_greedy_wins_easy_target() {
    Level lv = make_level(50, 30, 123, 777);  // 极低目标 → 必胜
    auto r = greedy_play(lv);
    CHECK(r.won, "easy target -> won");
}

static void test_greedy_deterministic() {
    Level lv = make_level(1000, 30, 123, 555);
    auto r1 = greedy_play(lv);
    auto r2 = greedy_play(lv);
    CHECK(r1.score == r2.score, "same level -> same score");
    CHECK(r1.moves_used == r2.moves_used, "same level -> same moves used");
}

static void test_random_play() {
    Level lv = make_level(1000000, 20, 123, 777);
    auto r = random_play(lv);
    CHECK_EQ(r.moves_used, 20, "random plays all moves");
    auto a = random_play(lv);
    CHECK(a.score == r.score, "random deterministic with seed");
}

static void test_evaluate_gap_and_difficulty() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.move_limit = 20;
    lv.target_score = 2000;
    lv.seed = 1;
    auto e = evaluate_level(lv, 6);
    std::printf("  [eval] floor=%.0f ceil=%.0f gap=%.2f pass=%.2f diff=%s\n",
                e.floor_score, e.ceil_score, e.lfhc_gap, e.skilled_pass_rate, e.difficulty);
    CHECK(e.ceil_score >= e.floor_score, "skilled(greedy) >= unskilled(random) on average");
    CHECK(e.lfhc_gap >= 0.0, "non-negative LFHC gap");
    CHECK(e.skilled_pass_rate >= 0.0 && e.skilled_pass_rate <= 1.0, "pass rate in [0,1]");
}

static void test_rhythm_quality() {
    std::vector<int> decreasing = {10, 9, 8, 4, 3, 2};  // 前松后紧
    std::vector<int> flat = {5, 5, 5, 5, 5, 5};
    CHECK(rhythm_quality(decreasing) > rhythm_quality(flat), "front-loose-back-tight scores higher than flat");
    CHECK(rhythm_quality(flat) <= 0.01, "flat curve ~ 0 rhythm");
    std::vector<int> tiny = {3, 1};
    CHECK_EQ((int)(rhythm_quality(tiny) * 100), 0, "too-short curve -> 0");
}

static void test_solspace_curve_recorded() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.move_limit = 20;
    lv.target_score = 100000;  // 不可能 → 走满步
    lv.seed = 7;
    auto r = heuristic_play(lv, solver_panel()[0]);
    CHECK((int)r.solspace_curve.size() == r.moves_used, "curve has one entry per played move");
    CHECK(r.solspace_curve.size() > 0, "curve recorded");
}

static void test_objective_progress_rhythm_on_jelly() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.jelly.assign(8, std::vector<int>(8, 0));
    for (int i = 0; i < 8; ++i)
        for (int j = 0; j < 8; ++j)
            if ((i + j) % 3 == 0) lv.jelly[i][j] = 1;  // ~1/3 稀疏果冻
    lv.move_limit = 30;
    lv.seed = 7;
    lv.objectives = {{OBJ_CLEAR_JELLY, -1, 9999}};  // 不可能 → 走满步、果冻耗尽
    auto curve = objective_progress_curve(lv);
    CHECK((int)curve.size() >= 4, "progress curve recorded");
    CHECK(rhythm_quality(curve) > 0.0, "jelly progress-moves decrease as jelly depletes -> positive rhythm");
}

static void test_panel_vote() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.move_limit = 20;
    lv.target_score = 2000;
    lv.seed = 1;
    auto e = evaluate_level(lv, 4);
    CHECK(e.panel_pass >= 0.0 && e.panel_pass <= 1.0, "panel_pass in [0,1]");
    CHECK(e.skilled_pass_rate >= e.panel_pass - 1e-9, "best archetype pass >= panel average");
    CHECK(e.ceil_score >= e.floor_score, "best archetype >= random floor");
}

static void test_archetypes_differ() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.move_limit = 15;
    lv.seed = 7;
    lv.objectives = {{OBJ_COLLECT, 0, 9999}};
    Heuristic rusher{"r", 100, 0.01, 0};
    Heuristic scorer{"s", 0, 1, 0};
    auto r = heuristic_play(lv, rusher);
    auto s = heuristic_play(lv, scorer);
    int r0 = !r.collected.empty() ? r.collected[0] : 0;
    int s0 = !s.collected.empty() ? s.collected[0] : 0;
    CHECK(r0 >= s0, "objective-rusher collects >= score-blind scorer of target species");
}

static void test_evaluate_deterministic() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.move_limit = 20;
    lv.target_score = 2000;
    lv.seed = 1;
    auto e1 = evaluate_level(lv, 6);
    auto e2 = evaluate_level(lv, 6);
    CHECK(e1.lfhc_gap == e2.lfhc_gap, "evaluate deterministic (gap)");
    CHECK(e1.skilled_pass_rate == e2.skilled_pass_rate, "evaluate deterministic (pass)");
}

static void test_objectives_met_helper() {
    Level lv;
    lv.objectives = {{OBJ_COLLECT, 0, 3}, {OBJ_SCORE, -1, 100}};
    CHECK(objectives_met(lv, 100, {5, 0}), "both objectives met");
    CHECK(!objectives_met(lv, 99, {5, 0}), "score objective not met");
    CHECK(!objectives_met(lv, 100, {2, 0}), "collect objective not met");
    Level legacy;  // 无 objectives → 旧式按 target_score
    legacy.target_score = 50;
    CHECK(objectives_met(legacy, 50, {}), "legacy: score>=target wins");
    CHECK(!objectives_met(legacy, 49, {}), "legacy: below target");
}

static void test_greedy_wins_collect_objective() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.move_limit = 20;
    lv.seed = 7;
    lv.objectives = {{OBJ_COLLECT, 0, 5}};  // 收集 5 个 species 0
    auto r = greedy_play(lv);
    CHECK(r.won, "greedy collects 5 of species 0 within 20 moves");
}

static void test_objectives_met_jelly() {
    Level lv;
    lv.objectives = {{OBJ_CLEAR_JELLY, -1, 10}};
    CHECK(objectives_met(lv, 0, {}, 10), "jelly target met");
    CHECK(!objectives_met(lv, 0, {}, 9), "jelly target not met");
}

static void test_greedy_clears_jelly_objective() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(6, 6, lv.species, gen);
    lv.jelly.assign(6, std::vector<int>(6, 1));  // 全盘果冻
    lv.move_limit = 30;
    lv.seed = 7;
    lv.objectives = {{OBJ_CLEAR_JELLY, -1, 8}};  // 清 8 层
    auto r = greedy_play(lv);
    CHECK(r.won, "greedy clears 8 jelly layers within 30 moves");
}

static void test_objectives_met_blocker() {
    Level lv;
    lv.objectives = {{OBJ_CLEAR_BLOCKER, -1, 10}};
    CHECK(objectives_met(lv, 0, {}, 0, 10), "blocker target met");
    CHECK(!objectives_met(lv, 0, {}, 0, 9), "blocker target not met");
}

static void test_greedy_clears_blocker_objective() {
    std::mt19937 gen(123);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.coat.assign(8, std::vector<int>(8, 0));
    for (int i = 0; i < 8; ++i) lv.coat[i][i] = 1;  // 对角线散布 8 个锁
    lv.move_limit = 40;
    lv.seed = 7;
    lv.objectives = {{OBJ_CLEAR_BLOCKER, -1, 5}};  // 破 5 层
    auto r = greedy_play(lv);
    CHECK(r.won, "greedy breaks 5 coat layers within 40 moves");
}

static void test_play_reshuffles_on_deadlock() {
    // 死局开局（6x6 对角条纹 (x+2y)%3：各行各列相邻/隔位均不同色 → 无任何合法交换；
    // 但每色 12 个，多重集可消 → 洗牌能救活）。修复后求解器应洗牌续玩，而非 0 步即停。
    Grid deadlock;
    for (int y = 0; y < 6; ++y) {
        std::vector<int> row;
        for (int x = 0; x < 6; ++x) row.push_back((x + 2 * y) % 3);
        deadlock.push_back(row);
    }
    CHECK(!has_legal_move(deadlock), "sanity: crafted board is a real deadlock");
    Level lv;
    lv.init_board = deadlock;
    lv.species = {0, 1, 2};
    lv.target_score = 100000;  // 大目标 → 不会因分数提前赢
    lv.move_limit = 5;
    lv.seed = 3;
    auto res = greedy_play(lv);
    CHECK(res.moves_used > 0, "greedy_play reshuffles past opening deadlock and makes moves");
}

// 滚动关：feed 全空=挖穿。
static void test_feed_drained_helper() {
    std::vector<std::deque<int>> none;
    CHECK(feed_drained(none), "no columns counts as drained");
    std::vector<std::deque<int>> f(2);
    f[0] = {1};
    CHECK(!feed_drained(f), "a non-empty column = not drained");
    f[0].clear();
    CHECK(feed_drained(f), "all columns empty = drained");
}

// 造滚动关：8x8 初盘 + 每列 depth 格随机 feed。
static Level make_scroll(int move_limit, int depth, uint32_t seed) {
    std::mt19937 gen(seed);
    Level lv;
    lv.species = {0, 1, 2, 3, 4};
    lv.init_board = make_board(8, 8, lv.species, gen);
    lv.is_scrolling = true;
    lv.move_limit = move_limit;
    lv.seed = seed;
    std::uniform_int_distribution<int> dist(0, 4);
    lv.feed.assign(8, {});
    for (int x = 0; x < 8; ++x)
        for (int i = 0; i < depth; ++i)
            lv.feed[x].push_back(lv.species[dist(gen)]);
    return lv;
}

// 浅 feed + 步数足 → 技巧玩家挖穿(won=feed 清空)。
static void test_scroll_dig_through() {
    Level lv = make_scroll(300, 3, 42);  // 每列3格=24总，300步绰绰有余
    PlayResult r = smart_greedy_play(lv);
    CHECK(r.won, "scroll: skilled player digs through shallow feed");
}

// 深 feed + 步数极少 → 挖不穿(未胜)。
static void test_scroll_too_deep_few_moves() {
    Level lv = make_scroll(2, 40, 7);  // 每列40格(5页)，仅2步
    PlayResult r = smart_greedy_play(lv);
    CHECK(!r.won, "scroll: 2 moves cannot drain a 5-page feed");
}

int main() {
    test_objectives_met_helper();
    test_greedy_wins_collect_objective();
    test_objectives_met_jelly();
    test_greedy_clears_jelly_objective();
    test_objectives_met_blocker();
    test_greedy_clears_blocker_objective();
    test_move_value();
    test_smart_greedy_pursues_collect();
    test_smart_greedy_pursues_jelly();
    test_greedy_plays_out_impossible_target();
    test_greedy_wins_easy_target();
    test_greedy_deterministic();
    test_random_play();
    test_evaluate_gap_and_difficulty();
    test_rhythm_quality();
    test_solspace_curve_recorded();
    test_objective_progress_rhythm_on_jelly();
    test_panel_vote();
    test_archetypes_differ();
    test_evaluate_deterministic();
    test_play_reshuffles_on_deadlock();
    test_feed_drained_helper();
    test_scroll_dig_through();
    test_scroll_too_deep_few_moves();
    return report();
}
