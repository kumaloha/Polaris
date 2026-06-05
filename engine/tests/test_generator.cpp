// 生成-评估闭环单测。
#include "check.hpp"
#include "../include/generator.hpp"

using namespace me;

static void test_generate_curates_library() {
    GenConfig cfg;
    cfg.move_limit = 16;
    cfg.trials = 4;
    cfg.min_gap = 0.10;
    cfg.base_seed = 1;
    auto lib = generate_and_test(cfg, 8, 120);
    CHECK(!lib.empty(), "produced at least one level");
    CHECK((int)lib.size() <= 8, "no more than requested count");
    int n_collect = 0, n_score = 0, n_jelly = 0, n_blocker = 0;
    for (const auto& gl : lib) {
        CHECK(gl.lfhc_gap >= cfg.min_gap, "every kept level meets min depth");
        CHECK(gl.skilled_pass > 0.0, "every kept level is solvable by the goal-directed ceiling");
        CHECK(gl.rhythm >= 0.0, "every kept level has a rhythm score");
        if (gl.level.objectives.empty()) {
            n_score++;
            CHECK(gl.level.target_score > (int)gl.floor_score, "SCORE target above floor (casual struggles)");
            CHECK(gl.level.target_score <= (int)gl.ceil_score + 1, "SCORE target at/below ceil (skilled passes)");
        } else {
            const auto& o = gl.level.objectives[0];
            CHECK(o.target >= 1, "objective target >= 1");
            if (o.type == OBJ_COLLECT) {
                n_collect++;
            } else if (o.type == OBJ_CLEAR_JELLY) {
                n_jelly++;
                CHECK(!gl.level.jelly.empty(), "JELLY level carries a jelly layer");
            } else if (o.type == OBJ_CLEAR_BLOCKER) {
                n_blocker++;
                CHECK(!gl.level.coat.empty(), "BLOCKER level carries a coat layer");
            }
        }
    }
    CHECK(n_collect + n_jelly + n_blocker >= 1, "at least one non-SCORE (variety) level produced");
    if (!lib.empty()) {
        const char* kinds[] = {"SCORE", "COLLECT", "JELLY", "BLOCKER"};  // 按 ObjType 序
        const auto& s = lib[0].level;
        const char* kind = s.objectives.empty() ? "SCORE" : kinds[s.objectives[0].type];
        std::printf("  [gen] kept=%d (score=%d collect=%d jelly=%d blocker=%d)  sample: %s gap=%.2f rhythm=%.2f diff=%s\n",
                    (int)lib.size(), n_score, n_collect, n_jelly, n_blocker, kind, lib[0].lfhc_gap, lib[0].rhythm, lib[0].difficulty);
    }
}

static void test_generate_deterministic() {
    GenConfig cfg;
    cfg.move_limit = 16;
    cfg.trials = 4;
    cfg.base_seed = 1;
    auto a = generate_and_test(cfg, 3, 40);
    auto b = generate_and_test(cfg, 3, 40);
    CHECK(a.size() == b.size(), "deterministic count");
    if (!a.empty() && !b.empty())
        CHECK(a[0].level.target_score == b[0].level.target_score, "deterministic target");
}

static void test_generate_for_difficulty() {
    GenConfig cfg;
    cfg.move_limit = 16;
    cfg.trials = 6;
    cfg.min_gap = 0.10;
    cfg.base_seed = 1;
    auto hard = generate_for_difficulty(cfg, band_hard(), 3, 150);
    CHECK(!hard.empty(), "produced HARD levels on request");
    for (const auto& gl : hard) {
        CHECK(gl.skilled_pass >= 0.1 - 1e-9 && gl.skilled_pass <= 0.4 + 1e-9, "HARD: skilled_pass in [0.1,0.4]");
        CHECK(std::string(gl.difficulty) == "HARD", "labeled HARD");
    }
    auto easy = generate_for_difficulty(cfg, band_easy(), 3, 150);
    CHECK(!easy.empty(), "produced EASY levels on request");
    for (const auto& gl : easy)
        CHECK(gl.skilled_pass >= 0.8 - 1e-9, "EASY: skilled_pass >= 0.8");
    if (!hard.empty())
        std::printf("  [gen-target] HARD kept=%d pass=%.2f | EASY kept=%d pass=%.2f\n",
                    (int)hard.size(), hard[0].skilled_pass, (int)easy.size(),
                    easy.empty() ? -1.0 : easy[0].skilled_pass);
}

static void test_fi2pop() {
    GenConfig cfg;
    cfg.move_limit = 16;
    cfg.trials = 4;
    cfg.min_gap = 0.10;
    cfg.base_seed = 1;
    auto lib = generate_fi2pop(cfg, band_medium(), 3, 8, 4);
    CHECK(!lib.empty(), "FI2Pop produced feasible levels");
    for (const auto& gl : lib) {
        Grid b = gl.level.init_board;
        const std::vector<std::vector<int>>* coat = gl.level.coat.empty() ? nullptr : &gl.level.coat;
        CHECK(has_legal_move(b, coat), "FI2Pop output has a legal move (feasible)");
        CHECK(gl.skilled_pass > 0.0, "FI2Pop output is objective-solvable (feasible)");
    }
    if (!lib.empty())
        std::printf("  [fi2pop] kept=%d sample diff=%s pass=%.2f gap=%.2f\n",
                    (int)lib.size(), lib[0].difficulty, lib[0].skilled_pass, lib[0].lfhc_gap);
}

// 滚动关生成：按难度带二分步数，产出带 feed 的可解滚动关 + 确定性。
static void test_generate_scroll_difficulty() {
    ScrollConfig cfg;
    cfg.depth_pages = 3;
    cfg.trials = 4;
    cfg.base_seed = 1;
    GeneratedLevel gl = generate_scroll_for_difficulty(cfg, band_medium(), 123);
    CHECK(gl.level.is_scrolling, "scroll gen: level flagged is_scrolling");
    CHECK_EQ((int)gl.level.feed.size(), 8, "scroll gen: one feed queue per column");
    int total = 0;
    for (auto& c : gl.level.feed) total += (int)c.size();
    CHECK_EQ(total, 8 * 3 * 8, "scroll gen: feed depth = w * depth_pages * h");
    CHECK(gl.level.move_limit > 0, "scroll gen: calibrated a positive move_limit");
    CHECK(gl.skilled_pass >= 0.0 && gl.skilled_pass <= 1.0, "scroll gen: skilled_pass is a rate");
    GeneratedLevel gl2 = generate_scroll_for_difficulty(cfg, band_medium(), 123);
    CHECK_EQ(gl2.level.move_limit, gl.level.move_limit, "scroll gen deterministic (move_limit)");
    CHECK(gl2.skilled_pass == gl.skilled_pass, "scroll gen deterministic (pass)");
    std::printf("  [scroll] diff=%s moves=%d pass=%.2f feed=%d/col\n",
                gl.difficulty, gl.level.move_limit, gl.skilled_pass, 3 * 8);
}

// 巧克力关生成：按难度带产 CLEAR_CHOCO 关，带初始巧克力层 + 标定到带内 + 可解。
static void test_generate_choco_difficulty() {
    GenConfig cfg;
    cfg.w = 9; cfg.h = 9; cfg.species = {0, 1, 2, 3, 4};
    cfg.move_limit = 25; cfg.trials = 8;
    cfg.choco_density = 0.10; cfg.min_choco = 3;
    cfg.base_seed = 12345u;

    auto easy = generate_choco_for_difficulty(cfg, band_easy(), 2, 400);
    CHECK(!easy.empty(), "produced EASY chocolate levels on request");
    for (const auto& gl : easy) {
        CHECK(!gl.level.choco.empty(), "CHOCO level carries a chocolate layer");
        CHECK_EQ((int)gl.level.objectives.size(), 1, "exactly one objective");
        CHECK(gl.level.objectives[0].type == OBJ_CLEAR_CHOCO, "objective is CLEAR_CHOCO");
        CHECK(gl.level.objectives[0].target >= 1, "choco target >= 1");
        int init_choco = 0;
        for (const auto& row : gl.level.choco) for (int v : row) init_choco += (v > 0);
        CHECK(init_choco >= cfg.min_choco, "initial chocolate count >= min_choco");
        CHECK(gl.skilled_pass >= 0.8 - 1e-9, "EASY: skilled_pass >= 0.8");
        CHECK(std::string(gl.difficulty) == "EASY", "labeled EASY");
    }

    auto hard = generate_choco_for_difficulty(cfg, band_hard(), 2, 400);
    CHECK(!hard.empty(), "produced HARD chocolate levels on request");
    for (const auto& gl : hard) {
        CHECK(gl.skilled_pass >= 0.1 - 1e-9 && gl.skilled_pass <= 0.4 + 1e-9, "HARD: skilled_pass in [0.1,0.4]");
        CHECK(gl.level.objectives[0].type == OBJ_CLEAR_CHOCO, "HARD objective is CLEAR_CHOCO");
    }
    // 标定有效性：HARD 目标通过率应低于 EASY（蔓延压力 + 更高 target 让难度真分化）
    if (!easy.empty() && !hard.empty())
        CHECK(easy[0].skilled_pass >= hard[0].skilled_pass - 1e-9, "EASY pass >= HARD pass (difficulty separates)");

    // 确定性：同配置两次生成 → 同 target
    auto a = generate_choco_for_difficulty(cfg, band_medium(), 1, 400);
    auto b = generate_choco_for_difficulty(cfg, band_medium(), 1, 400);
    CHECK(a.size() == b.size(), "choco gen deterministic count");
    if (!a.empty() && !b.empty())
        CHECK_EQ(a[0].level.objectives[0].target, b[0].level.objectives[0].target, "choco gen deterministic target");

    if (!easy.empty())
        std::printf("  [gen-choco] EASY kept=%d pass=%.2f target=%d | HARD kept=%d pass=%.2f target=%d\n",
                    (int)easy.size(), easy[0].skilled_pass, easy[0].level.objectives[0].target,
                    (int)hard.size(), hard.empty() ? -1.0 : hard[0].skilled_pass,
                    hard.empty() ? -1 : hard[0].level.objectives[0].target);
}

int main() {
    test_generate_curates_library();
    test_generate_for_difficulty();
    test_generate_choco_difficulty();
    test_fi2pop();
    test_generate_deterministic();
    test_generate_scroll_difficulty();
    return report();
}
