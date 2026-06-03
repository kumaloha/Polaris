#pragma once
// 极简零依赖测试框架（镜像 godot/tests 的 runner 风格）。
#include <cstdio>
#include <string>

inline int g_total = 0;
inline int g_fail = 0;

#define CHECK(cond, msg)                          \
    do {                                          \
        ++g_total;                                \
        if (!(cond)) {                            \
            ++g_fail;                             \
            std::printf("  FAIL: %s\n", msg);     \
        }                                         \
    } while (0)

#define CHECK_EQ(actual, expected, msg)                                       \
    do {                                                                      \
        ++g_total;                                                            \
        auto _a = (actual);                                                   \
        auto _e = (expected);                                                 \
        if (!(_a == _e)) {                                                    \
            ++g_fail;                                                         \
            std::printf("  FAIL: %s (expected %lld, got %lld)\n", msg,        \
                        (long long)_e, (long long)_a);                        \
        }                                                                     \
    } while (0)

inline int report() {
    std::printf("\nC++ tests: %d   failed: %d\n", g_total, g_fail);
    return g_fail ? 1 : 0;
}
