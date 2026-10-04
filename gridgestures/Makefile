CXX ?= g++
CXXFLAGS := -shared -fPIC -O2 -g -std=c++23 \
	$(shell pkg-config --cflags pixman-1 libdrm hyprland pangocairo libinput libudev wayland-server xkbcommon)

all: gridgestures.so

gridgestures.so: gridgestures.cpp
	$(CXX) $(CXXFLAGS) $< -o $@

clean:
	rm -f gridgestures.so
