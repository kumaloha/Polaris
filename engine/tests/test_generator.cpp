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
    auto lib = generate_and_test(cfg, 6, 80);
    CHECK(!lib.empty(), "produced at least one level");
    CHECK((int)lib.size() <= 6, "no more than requested count");
    int n_collect = 0, n_score = 0;
    for (const auto& gl : lib) {
        CHECK(gl.lfhc_gap >= cfg.min_gap, "every kept level meets min depth");
        if (gl.level.objectives.empty()) {
            n_score++;
            CHECK(gl.level.target_score > (int)gl.floor_score, "SCORE target above floor (casual struggles)");
            CHECK(gl.level.target_score <= (int)gl.ceil_score + 1, "SCORE target at/below ceil (skilled passes)");
        } else {
            n_collect++;
            CHECK(gl.level.objectives[0].type == OBJ_COLLECT, "objective is COLLECT");
            CHECK(gl.level.objectives[0].target >= 1, "COLLECT target >= 1");
        }
    }
    CHECK(n_collect >= 1, "at least one COLLECT level produced");
    if (!lib.empty()) {
        const char* kind = lib[0].level.objectives.empty() ? "SCORE" : "COLLECT";
        std::printf("  [gen] kept=%d (score=%d collect=%d)  sample: %s gap=%.2f diff=%s\n",
                    (int)lib.size(), n_score, n_collect, kind, lib[0].lfhc_gap, lib[0].difficulty);
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

int main() {
    test_generate_curates_library();
    test_generate_deterministic();
    return report();
}
