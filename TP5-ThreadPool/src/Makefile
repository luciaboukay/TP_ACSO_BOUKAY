# # Compiler settings - Can change to clang++ if preferred
# CXX = g++
# CXXFLAGS = -std=c++11 -Wall -pthread -g

# # Build targets
# TARGET = threadpool
# SRC = thread-pool.cc Semaphore.cc main.cc

# # Link the target with object files
# $(TARGET): $(SRC)
# 	$(CXX) $(CXXFLAGS) -o $@ $^

# # Clean up build artifacts
# clean:
# 	rm -f $(TARGET) $(OBJ)

# .PHONY: all clean

# Compiler settings - Can change to clang++ if preferred
CXX = g++
CXXFLAGS = -std=c++11 -Wall -pthread -g

# Common source files (without main files)
COMMON_SRC = thread-pool.cc Semaphore.cc

# Build targets
all: main tptest tpcustomtest

# Main demo program
main: $(COMMON_SRC) main.cc
	$(CXX) $(CXXFLAGS) -o $@ $^

# First test program
tptest: $(COMMON_SRC) tptest.cc
	$(CXX) $(CXXFLAGS) -o $@ $^

# Custom test program
tpcustomtest: $(COMMON_SRC) tpcustomtest.cc
	$(CXX) $(CXXFLAGS) -o $@ $^

# Clean up build artifacts
clean:
	rm -f main tptest tpcustomtest

.PHONY: all clean