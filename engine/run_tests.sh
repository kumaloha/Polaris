#!/bin/bash
# 编译并运行 C++ 引擎单测（引擎 + 求解器两套）。退出码：0 全过 / 非0 有失败或编译错。
cd "$(dirname "$0")" || exit 2
mkdir -p build
clang++ -std=c++20 -Wall tests/test_match_engine.cpp -o build/test_engine || exit 2
clang++ -std=c++20 -Wall tests/test_solver.cpp -o build/test_solver || exit 2
clang++ -std=c++20 -Wall tests/test_generator.cpp -o build/test_generator || exit 2
./build/test_engine; e1=$?
./build/test_solver; e2=$?
./build/test_generator; e3=$?
exit $(( e1 + e2 + e3 ))
