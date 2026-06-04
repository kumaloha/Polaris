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

int main() {
    test_generate_curates_library();
    test_generate_for_difficulty();
    test_generate_deterministic();
    return report();
}
