# CMakeの最低バージョンを指定 (CUDAサポートが安定している3.18以降を推奨)
cmake_minimum_required(VERSION 3.18)

# プロジェクト名と使用する言語にCUDAを追加
project(SimpleRayTracing LANGUAGES CXX CUDA)

# C++の標準を指定
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED YES)

# 実行ファイルを作成する (main.cpp -> main.cu に変更)
add_executable(SimpleRayTracing src/main.cu)