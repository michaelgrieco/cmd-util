
# directories
OBJ_DIR=../obj
BIN_DIR=../bin

# c flags
CXX=gcc
CFLAGS ?= -g3
IFLAGS ?= -I../include
LFLAGS ?= -L$(BIN_DIR)

# file lists
DEPS=$(wildcard *.h) $(wildcard ../include/*.h)
SRCS=$(wildcard *.c)
OBJS=$(SRCS:%.c=$(OBJ_DIR)/%.o)

all: $(BIN_DIR) $(OBJ_DIR) $(OBJS) fp trim_md_list_spacing

$(BIN_DIR):
	mkdir $(BIN_DIR)

$(OBJ_DIR):
	mkdir $(OBJ_DIR)

# compile
$(OBJ_DIR)/%.o: %.c $(DEPS) $(OBJ_DIR)
	$(CXX) -c -o $@ $< $(CFLAGS) $(IFLAGS)

# link
fp: $(OBJ_DIR)/fp.o $(OBJ_DIR)/text.o
	$(CXX) -o $(BIN_DIR)/$@ $^ $(CFLAGS) $(LFLAGS)

trim_md_list_spacing: $(OBJ_DIR)/trim_md_list_spacing.o
	$(CXX) -o $(BIN_DIR)/$@ $^ $(CFLAGS) $(LFLAGS)

# clean
clean:
	$(RM) $(wildcard $(OBJ_DIR)/*.o) $(wildcard $(BIN_DIR)/*.exe)
