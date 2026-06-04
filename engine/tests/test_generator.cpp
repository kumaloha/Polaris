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

int main() {
    test_generate_curates_library();
    test_generate_for_difficulty();
    test_fi2pop();
    test_generate_deterministic();
    test_generate_scroll_difficulty();
    return report();
}
