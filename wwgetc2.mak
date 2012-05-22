CFLAGS = -g
OBJS = wwgetc2.o url.o common.o
TARGET = wwgetc2

$(TARGET): $(OBJS)
clean:
	rm $(OBJS) $(TARGET)