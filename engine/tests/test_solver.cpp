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

static void test_mc_plays_and_scores() {
    Level lv = make_level(1000000, 10, 123, 777);  // 短局 + 小参数（测试提速）
    auto r = mc_play(lv, 4, 3);
    CHECK_EQ(r.moves_used, 10, "mc plays all moves");
    CHECK(r.score > 0, "mc scores something");
}

static void test_mc_deterministic() {
    Level lv = make_level(1000000, 10, 123, 555);
    auto a = mc_play(lv, 4, 3);
    auto b = mc_play(lv, 4, 3);
    CHECK(a.score == b.score, "mc deterministic (same level -> same score)");
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

int main() {
    test_objectives_met_helper();
    test_greedy_wins_collect_objective();
    test_objectives_met_jelly();
    test_greedy_clears_jelly_objective();
    test_greedy_plays_out_impossible_target();
    test_greedy_wins_easy_target();
    test_greedy_deterministic();
    test_mc_plays_and_scores();
    test_mc_deterministic();
    test_random_play();
    test_evaluate_gap_and_difficulty();
    test_evaluate_deterministic();
    return report();
}
