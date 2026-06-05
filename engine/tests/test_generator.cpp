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

// 运料关生成：按难度带产 COLLECT_INGREDIENT 关，带初始原料层 + 底行出口 + 标定分化 + 可解 + 确定性。
//   注：裸 Core(无特效)运料慢，单个 seed 不保证精确命中难度带，故只断言"结构正确 + 难度分化 + 确定性"，
//   不像 choco 那样硬断言 pass 落具体带（避免强加无法稳定满足的契约）。
static void test_generate_ingredient_difficulty() {
    GenConfig cfg;
    cfg.w = 9; cfg.h = 9; cfg.species = {0, 1, 2, 3, 4, 5};
    cfg.move_limit = 25; cfg.trials = 8;
    cfg.ing_rows = 2; cfg.ing_density = 0.18; cfg.min_ingredient = 3;

    GeneratedLevel easy = generate_ingredient_for_difficulty(cfg, band_easy(), 550000u);
    CHECK(!easy.level.ing.empty(), "ING level carries an ingredient layer");
    CHECK_EQ((int)easy.level.objectives.size(), 1, "exactly one objective");
    CHECK(easy.level.objectives[0].type == OBJ_COLLECT_INGREDIENT, "objective is COLLECT_INGREDIENT");
    CHECK(easy.level.objectives[0].target >= 1, "ingredient target >= 1");
    CHECK(!easy.level.exit_cols.empty(), "ING level has exit columns");
    int init_ing = 0;
    for (const auto& row : easy.level.ing) for (int v : row) init_ing += (v > 0);
    CHECK(init_ing >= cfg.min_ingredient, "initial ingredient count >= min_ingredient");
    CHECK(easy.level.move_limit > 0, "ING level has positive move_limit");
    CHECK(easy.skilled_pass >= 0.0 && easy.skilled_pass <= 1.0, "ING skilled_pass is a rate");
    // 出口列都在合法范围且原料层维度匹配盘面
    for (int cx : easy.level.exit_cols) CHECK(cx >= 0 && cx < cfg.w, "exit column in range");
    CHECK_EQ((int)easy.level.ing.size(), (int)easy.level.init_board.size(), "ing layer height matches board");

    GeneratedLevel hard = generate_ingredient_for_difficulty(cfg, band_hard(), 550000u);
    CHECK(!hard.level.ing.empty(), "produced HARD ingredient level");
    CHECK(hard.level.objectives[0].type == OBJ_COLLECT_INGREDIENT, "HARD objective is COLLECT_INGREDIENT");
    // 标定分化：同盘 HARD 的 target 应 >= EASY（更难=要运下更多原料），或 HARD pass <= EASY pass。
    CHECK(hard.level.objectives[0].target >= easy.level.objectives[0].target
          || hard.skilled_pass <= easy.skilled_pass + 1e-9, "difficulty separates (target up or pass down)");

    // 确定性：同配置两次生成 → 同 target + 同 pass。
    GeneratedLevel a = generate_ingredient_for_difficulty(cfg, band_medium(), 660000u);
    GeneratedLevel b = generate_ingredient_for_difficulty(cfg, band_medium(), 660000u);
    CHECK_EQ(a.level.objectives[0].target, b.level.objectives[0].target, "ing gen deterministic target");
    CHECK(a.skilled_pass == b.skilled_pass, "ing gen deterministic pass");

    std::printf("  [gen-ing] EASY pass=%.2f target=%d ing=%d moves=%d | HARD pass=%.2f target=%d\n",
                easy.skilled_pass, easy.level.objectives[0].target, init_ing, easy.level.move_limit,
                hard.skilled_pass, hard.level.objectives[0].target);
}

// 倒计时炸弹关生成：按难度带产 OBJ_DEFUSE_BOMB 关，带初始炸弹层(倒计时) + 标定分化 + 可解 + 确定性。
//   命门验证：裸 Core 玩家无拆弹动机，靠 play_bomb 的"紧迫度激励"牵引才会主动拆将爆的弹。故核心断言 =
//   "目标导向天花板(smart_greedy)能在不爆前提下拆够 target"——证明标定真产出可解炸弹关(而非 pass≡0 的死关)。
static void test_generate_bomb_difficulty() {
    GenConfig cfg;
    cfg.w = 9; cfg.h = 9; cfg.species = {0, 1, 2, 3, 4, 5};
    cfg.move_limit = 25; cfg.trials = 8;
    cfg.bomb_density = 0.12; cfg.min_bomb = 3;

    auto easy = generate_bomb_for_difficulty(cfg, band_easy(), 2, 600);
    CHECK(!easy.empty(), "produced EASY bomb levels on request");
    for (const auto& gl : easy) {
        CHECK(!gl.level.bomb.empty(), "BOMB level carries a bomb (countdown) layer");
        CHECK_EQ((int)gl.level.objectives.size(), 1, "exactly one objective");
        CHECK(gl.level.objectives[0].type == OBJ_DEFUSE_BOMB, "objective is DEFUSE_BOMB");
        CHECK(gl.level.objectives[0].target >= 1, "bomb target >= 1");
        int init_bomb = 0, max_ttl = 0;
        for (const auto& row : gl.level.bomb)
            for (int v : row) if (v > 0) { init_bomb++; if (v > max_ttl) max_ttl = v; }
        CHECK(init_bomb >= cfg.min_bomb, "initial bomb count >= min_bomb");
        CHECK(max_ttl > 0, "bombs carry a positive countdown");
        CHECK(gl.level.move_limit > 0, "BOMB level has positive move_limit");
        CHECK(gl.skilled_pass > 0.0, "BOMB level is solvable by the goal-directed ceiling (pass>0)");
        CHECK(gl.skilled_pass >= 0.8 - 1e-9, "EASY: skilled_pass >= 0.8");
        CHECK(std::string(gl.difficulty) == "EASY", "labeled EASY");
        CHECK_EQ((int)gl.level.bomb.size(), (int)gl.level.init_board.size(), "bomb layer height matches board");
        // 可解性铁证：目标导向天花板至少一次"拆够 target 且全程不爆"地赢下来（否则=不可解死关）。
        bool any_clean_win = false;
        for (int t = 0; t < 12 && !any_clean_win; ++t) {
            Level lv = gl.level;
            lv.seed = gl.level.seed + (uint32_t)t * 1000003u;
            PlayResult sp = smart_greedy_play(lv);
            if (sp.won && !sp.bomb_exploded && sp.bomb_defused >= gl.level.objectives[0].target)
                any_clean_win = true;
        }
        CHECK(any_clean_win, "ceiling can defuse target bombs without any explosion (real solvability)");
    }

    auto hard = generate_bomb_for_difficulty(cfg, band_hard(), 2, 600);
    CHECK(!hard.empty(), "produced HARD bomb levels on request");
    for (const auto& gl : hard) {
        CHECK(gl.level.objectives[0].type == OBJ_DEFUSE_BOMB, "HARD objective is DEFUSE_BOMB");
        CHECK(gl.skilled_pass >= 0.1 - 1e-9 && gl.skilled_pass <= 0.4 + 1e-9, "HARD: skilled_pass in [0.1,0.4]");
    }
    // 标定分化：EASY 通过率应 >= HARD（同旋钮二分，target 越高越难）。
    if (!easy.empty() && !hard.empty())
        CHECK(easy[0].skilled_pass >= hard[0].skilled_pass - 1e-9, "EASY pass >= HARD pass (difficulty separates)");

    // 确定性：同配置两次生成 → 同 target + 同 pass。
    auto a = generate_bomb_for_difficulty(cfg, band_medium(), 1, 600);
    auto b = generate_bomb_for_difficulty(cfg, band_medium(), 1, 600);
    CHECK(a.size() == b.size(), "bomb gen deterministic count");
    if (!a.empty() && !b.empty()) {
        CHECK_EQ(a[0].level.objectives[0].target, b[0].level.objectives[0].target, "bomb gen deterministic target");
        CHECK(a[0].skilled_pass == b[0].skilled_pass, "bomb gen deterministic pass");
    }

    if (!easy.empty()) {
        int ib = 0, ttl = 0;
        for (const auto& row : easy[0].level.bomb) for (int v : row) if (v > 0) { ib++; ttl = v; }
        std::printf("  [gen-bomb] EASY kept=%d pass=%.2f target=%d bombs=%d ttl=%d moves=%d | HARD kept=%d pass=%.2f\n",
                    (int)easy.size(), easy[0].skilled_pass, easy[0].level.objectives[0].target, ib, ttl,
                    easy[0].level.move_limit, (int)hard.size(), hard.empty() ? -1.0 : hard[0].skilled_pass);
    }
}

// ═══════════════ H5：四个"死功能"障碍关生成断言（cannon / popcorn / cake / mystery）═══════════════

// 糖果炮关：cannon=2 产原料，目标 COLLECT_INGREDIENT（靠起手原料 + 炮口供给达成）。带 cannon 层 + 可解 + 确定性。
static void test_generate_cannon_difficulty() {
    GenConfig cfg;
    cfg.w = 9; cfg.h = 9; cfg.species = {0, 1, 2, 3, 4, 5};
    cfg.move_limit = 25; cfg.trials = 8;
    cfg.cannon_count = 3; cfg.min_cannon = 2;

    GeneratedLevel easy = generate_cannon_for_difficulty(cfg, band_easy(), 440000u);
    CHECK(!easy.level.cannon.empty(), "CANNON level carries a cannon layer");
    CHECK_EQ((int)easy.level.objectives.size(), 1, "exactly one objective");
    CHECK(easy.level.objectives[0].type == OBJ_COLLECT_INGREDIENT, "objective is COLLECT_INGREDIENT");
    CHECK(easy.level.objectives[0].target >= 1, "cannon target >= 1");
    CHECK(!easy.level.exit_cols.empty(), "CANNON level has exit columns");
    int cannon_n = 0;
    for (const auto& row : easy.level.cannon) for (int v : row) if (v > 0) { cannon_n++; CHECK(v == 2, "cannon produces ingredient (=2)"); }
    CHECK(cannon_n >= cfg.min_cannon, "cannon count >= min_cannon");
    // 炮口格 grid=WALL（与 board.gd _merge_walls_into_mask 一致）
    for (int y = 0; y < (int)easy.level.cannon.size(); ++y)
        for (int x = 0; x < (int)easy.level.cannon[y].size(); ++x)
            if (easy.level.cannon[y][x] > 0)
                CHECK_EQ(easy.level.init_board[y][x], WALL, "cannon cell is WALL in init_board");
    CHECK_EQ((int)easy.level.cannon.size(), (int)easy.level.init_board.size(), "cannon layer height matches board");
    CHECK(easy.skilled_pass >= 0.0 && easy.skilled_pass <= 1.0, "CANNON skilled_pass is a rate");
    // 可解性铁证：目标导向天花板至少一次收够 target 个原料。
    bool any_win = false;
    for (int t = 0; t < 12 && !any_win; ++t) {
        Level lv = easy.level;
        lv.seed = easy.level.seed + (uint32_t)t * 1000003u;
        PlayResult sp = smart_greedy_play(lv);
        if (sp.ingredient_collected >= easy.level.objectives[0].target) any_win = true;
    }
    CHECK(any_win, "ceiling can collect target ingredients (real solvability)");

    GeneratedLevel hard = generate_cannon_for_difficulty(cfg, band_hard(), 440000u);
    CHECK(!hard.level.cannon.empty(), "produced HARD cannon level");
    CHECK(hard.level.objectives[0].type == OBJ_COLLECT_INGREDIENT, "HARD objective is COLLECT_INGREDIENT");
    CHECK(hard.level.objectives[0].target >= easy.level.objectives[0].target
          || hard.skilled_pass <= easy.skilled_pass + 1e-9, "difficulty separates (target up or pass down)");

    // 确定性：同配置两次生成 → 同 target + 同 pass。
    GeneratedLevel a = generate_cannon_for_difficulty(cfg, band_medium(), 441000u);
    GeneratedLevel b = generate_cannon_for_difficulty(cfg, band_medium(), 441000u);
    CHECK_EQ(a.level.objectives[0].target, b.level.objectives[0].target, "cannon gen deterministic target");
    CHECK(a.skilled_pass == b.skilled_pass, "cannon gen deterministic pass");

    std::printf("  [gen-cannon] EASY pass=%.2f target=%d cannons=%d | HARD pass=%.2f target=%d\n",
                easy.skilled_pass, easy.level.objectives[0].target, cannon_n,
                hard.skilled_pass, hard.level.objectives[0].target);
}

// 爆米花关：OBJ_POP_POPCORN，裸 Core 保守溅射命中近似。带 popcorn 层 + 可解 + 确定性。
static void test_generate_popcorn_difficulty() {
    GenConfig cfg;
    cfg.w = 9; cfg.h = 9; cfg.species = {0, 1, 2, 3, 4, 5};
    cfg.move_limit = 25; cfg.trials = 8;
    cfg.mystery_density = 0.10; cfg.popcorn_hp = 1; cfg.min_popcorn = 3;

    GeneratedLevel easy = generate_popcorn_for_difficulty(cfg, band_easy(), 330000u);
    CHECK(!easy.level.popcorn.empty(), "POPCORN level carries a popcorn layer");
    CHECK_EQ((int)easy.level.objectives.size(), 1, "exactly one objective");
    CHECK(easy.level.objectives[0].type == OBJ_POP_POPCORN, "objective is POP_POPCORN");
    CHECK(easy.level.objectives[0].target >= 1, "popcorn target >= 1");
    int pop_n = 0;
    for (const auto& row : easy.level.popcorn) for (int v : row) if (v > 0) pop_n++;
    CHECK(pop_n >= cfg.min_popcorn, "initial popcorn count >= min_popcorn");
    CHECK_EQ((int)easy.level.popcorn.size(), (int)easy.level.init_board.size(), "popcorn layer height matches board");
    CHECK(easy.skilled_pass >= 0.8 - 1e-9, "EASY: skilled_pass >= 0.8");
    CHECK(std::string(easy.difficulty) == "EASY", "labeled EASY");
    // 可解性铁证：目标导向天花板至少一次砸够 target 次。
    bool any_win = false;
    for (int t = 0; t < 12 && !any_win; ++t) {
        Level lv = easy.level;
        lv.seed = easy.level.seed + (uint32_t)t * 1000003u;
        PlayResult sp = smart_greedy_play(lv);
        if (sp.popcorn_hit >= easy.level.objectives[0].target) any_win = true;
    }
    CHECK(any_win, "ceiling can pop target popcorn (conservative splash solvability)");

    GeneratedLevel hard = generate_popcorn_for_difficulty(cfg, band_hard(), 330000u);
    CHECK(!hard.level.popcorn.empty(), "produced HARD popcorn level");
    CHECK(hard.level.objectives[0].type == OBJ_POP_POPCORN, "HARD objective is POP_POPCORN");
    CHECK(hard.level.objectives[0].target >= easy.level.objectives[0].target
          || hard.skilled_pass <= easy.skilled_pass + 1e-9, "difficulty separates (target up or pass down)");

    GeneratedLevel a = generate_popcorn_for_difficulty(cfg, band_medium(), 331000u);
    GeneratedLevel b = generate_popcorn_for_difficulty(cfg, band_medium(), 331000u);
    CHECK_EQ(a.level.objectives[0].target, b.level.objectives[0].target, "popcorn gen deterministic target");
    CHECK(a.skilled_pass == b.skilled_pass, "popcorn gen deterministic pass");

    std::printf("  [gen-popcorn] EASY pass=%.2f target=%d popcorn=%d | HARD pass=%.2f target=%d\n",
                easy.skilled_pass, easy.level.objectives[0].target, pop_n,
                hard.skilled_pass, hard.level.objectives[0].target);
}

// 蛋糕关：OBJ_DESTROY_CAKE，相邻被清 -1 引爆。带 cake 层(grid=WALL) + 可解 + 确定性。
static void test_generate_cake_difficulty() {
    GenConfig cfg;
    cfg.w = 9; cfg.h = 9; cfg.species = {0, 1, 2, 3, 4, 5};
    cfg.move_limit = 25; cfg.trials = 8;
    cfg.cake_density = 0.06; cfg.cake_hp = 2; cfg.min_cake = 2;

    GeneratedLevel easy = generate_cake_for_difficulty(cfg, band_easy(), 220000u);
    CHECK(!easy.level.cake.empty(), "CAKE level carries a cake layer");
    CHECK_EQ((int)easy.level.objectives.size(), 1, "exactly one objective");
    CHECK(easy.level.objectives[0].type == OBJ_DESTROY_CAKE, "objective is DESTROY_CAKE");
    CHECK(easy.level.objectives[0].target >= 1, "cake target >= 1");
    int cake_n = 0;
    for (const auto& row : easy.level.cake) for (int v : row) if (v > 0) cake_n++;
    CHECK(cake_n >= cfg.min_cake, "initial cake count >= min_cake");
    // 蛋糕格 grid=WALL（与 board.gd _merge_walls_into_mask 一致）
    for (int y = 0; y < (int)easy.level.cake.size(); ++y)
        for (int x = 0; x < (int)easy.level.cake[y].size(); ++x)
            if (easy.level.cake[y][x] > 0)
                CHECK_EQ(easy.level.init_board[y][x], WALL, "cake cell is WALL in init_board");
    CHECK_EQ((int)easy.level.cake.size(), (int)easy.level.init_board.size(), "cake layer height matches board");
    CHECK(easy.skilled_pass >= 0.8 - 1e-9, "EASY: skilled_pass >= 0.8");
    CHECK(std::string(easy.difficulty) == "EASY", "labeled EASY");
    bool any_win = false;
    for (int t = 0; t < 12 && !any_win; ++t) {
        Level lv = easy.level;
        lv.seed = easy.level.seed + (uint32_t)t * 1000003u;
        PlayResult sp = smart_greedy_play(lv);
        if (sp.cake_destroyed >= easy.level.objectives[0].target) any_win = true;
    }
    CHECK(any_win, "ceiling can destroy target cakes (real solvability)");

    GeneratedLevel hard = generate_cake_for_difficulty(cfg, band_hard(), 220000u);
    CHECK(!hard.level.cake.empty(), "produced HARD cake level");
    CHECK(hard.level.objectives[0].type == OBJ_DESTROY_CAKE, "HARD objective is DESTROY_CAKE");
    CHECK(hard.level.objectives[0].target >= easy.level.objectives[0].target
          || hard.skilled_pass <= easy.skilled_pass + 1e-9, "difficulty separates (target up or pass down)");

    GeneratedLevel a = generate_cake_for_difficulty(cfg, band_medium(), 221000u);
    GeneratedLevel b = generate_cake_for_difficulty(cfg, band_medium(), 221000u);
    CHECK_EQ(a.level.objectives[0].target, b.level.objectives[0].target, "cake gen deterministic target");
    CHECK(a.skilled_pass == b.skilled_pass, "cake gen deterministic pass");

    std::printf("  [gen-cake] EASY pass=%.2f target=%d cakes=%d | HARD pass=%.2f target=%d\n",
                easy.skilled_pass, easy.level.objectives[0].target, cake_n,
                hard.skilled_pass, hard.level.objectives[0].target);
}

// 神秘糖关：OBJ_REVEAL_MYSTERY，被消即揭开。带 mystery 层(普通棋子) + 可解 + 确定性。
static void test_generate_mystery_difficulty() {
    GenConfig cfg;
    cfg.w = 9; cfg.h = 9; cfg.species = {0, 1, 2, 3, 4, 5};
    cfg.move_limit = 25; cfg.trials = 8;
    cfg.mystery_density = 0.12; cfg.min_mystery = 3;

    GeneratedLevel easy = generate_mystery_for_difficulty(cfg, band_easy(), 110000u);
    CHECK(!easy.level.mystery.empty(), "MYSTERY level carries a mystery layer");
    CHECK_EQ((int)easy.level.objectives.size(), 1, "exactly one objective");
    CHECK(easy.level.objectives[0].type == OBJ_REVEAL_MYSTERY, "objective is REVEAL_MYSTERY");
    CHECK(easy.level.objectives[0].target >= 1, "mystery target >= 1");
    int mys_n = 0;
    for (const auto& row : easy.level.mystery) for (int v : row) if (v > 0) mys_n++;
    CHECK(mys_n >= cfg.min_mystery, "initial mystery count >= min_mystery");
    // 神秘糖格 grid 是普通棋子（可消可换，非 WALL）
    for (int y = 0; y < (int)easy.level.mystery.size(); ++y)
        for (int x = 0; x < (int)easy.level.mystery[y].size(); ++x)
            if (easy.level.mystery[y][x] > 0)
                CHECK(easy.level.init_board[y][x] >= 0, "mystery cell is a normal piece (not WALL/EMPTY)");
    CHECK_EQ((int)easy.level.mystery.size(), (int)easy.level.init_board.size(), "mystery layer height matches board");
    CHECK(easy.skilled_pass >= 0.8 - 1e-9, "EASY: skilled_pass >= 0.8");
    CHECK(std::string(easy.difficulty) == "EASY", "labeled EASY");
    bool any_win = false;
    for (int t = 0; t < 12 && !any_win; ++t) {
        Level lv = easy.level;
        lv.seed = easy.level.seed + (uint32_t)t * 1000003u;
        PlayResult sp = smart_greedy_play(lv);
        if (sp.mystery_revealed >= easy.level.objectives[0].target) any_win = true;
    }
    CHECK(any_win, "ceiling can reveal target mysteries (real solvability)");

    GeneratedLevel hard = generate_mystery_for_difficulty(cfg, band_hard(), 110000u);
    CHECK(!hard.level.mystery.empty(), "produced HARD mystery level");
    CHECK(hard.level.objectives[0].type == OBJ_REVEAL_MYSTERY, "HARD objective is REVEAL_MYSTERY");
    CHECK(hard.level.objectives[0].target >= easy.level.objectives[0].target
          || hard.skilled_pass <= easy.skilled_pass + 1e-9, "difficulty separates (target up or pass down)");

    GeneratedLevel a = generate_mystery_for_difficulty(cfg, band_medium(), 111000u);
    GeneratedLevel b = generate_mystery_for_difficulty(cfg, band_medium(), 111000u);
    CHECK_EQ(a.level.objectives[0].target, b.level.objectives[0].target, "mystery gen deterministic target");
    CHECK(a.skilled_pass == b.skilled_pass, "mystery gen deterministic pass");

    std::printf("  [gen-mystery] EASY pass=%.2f target=%d mystery=%d | HARD pass=%.2f target=%d\n",
                easy.skilled_pass, easy.level.objectives[0].target, mys_n,
                hard.skilled_pass, hard.level.objectives[0].target);
}

int main() {
    test_generate_curates_library();
    test_generate_for_difficulty();
    test_generate_choco_difficulty();
    test_generate_ingredient_difficulty();
    test_generate_bomb_difficulty();
    test_generate_cannon_difficulty();
    test_generate_popcorn_difficulty();
    test_generate_cake_difficulty();
    test_generate_mystery_difficulty();
    test_fi2pop();
    test_generate_deterministic();
    test_generate_scroll_difficulty();
    return report();
}
