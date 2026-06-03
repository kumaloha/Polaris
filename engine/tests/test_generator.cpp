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
    auto lib = generate_and_test(cfg, 5, 60);
    CHECK(!lib.empty(), "produced at least one level");
    CHECK((int)lib.size() <= 5, "no more than requested count");
    for (const auto& gl : lib) {
        CHECK(gl.lfhc_gap >= cfg.min_gap, "every kept level meets min depth");
        CHECK(gl.level.target_score > (int)gl.floor_score, "target above floor (casual struggles)");
        CHECK(gl.level.target_score <= (int)gl.ceil_score + 1, "target at/below ceil (skilled can pass)");
    }
    if (!lib.empty()) {
        std::printf("  [gen] kept=%d/5  sample: gap=%.2f diff=%s target=%d (floor=%.0f ceil=%.0f)\n",
                    (int)lib.size(), lib[0].lfhc_gap, lib[0].difficulty,
                    lib[0].level.target_score, lib[0].floor_score, lib[0].ceil_score);
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
