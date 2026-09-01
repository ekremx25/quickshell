CXX ?= c++
CPPFLAGS ?=
CXXFLAGS ?= -O2 -pipe
LDFLAGS ?=
LDLIBS ?= -ldl

SAMPLER_FLAGS = -std=c++17 -DNDEBUG -fno-exceptions -fno-rtti \
	-fstack-protector-strong -fcf-protection -D_FORTIFY_SOURCE=3 \
	-Wall -Wextra -Wpedantic -Werror -ffile-prefix-map=$(CURDIR)=.
SAMPLER_LDFLAGS = -Wl,--as-needed -Wl,-z,relro -Wl,-z,now \
	-Wl,--build-id=none -s

.PHONY: all clean

all: activity-sampler

activity-sampler: activity-sampler.cpp
	LC_ALL=C $(CXX) $(CPPFLAGS) $(CXXFLAGS) $(SAMPLER_FLAGS) \
		$(LDFLAGS) $(SAMPLER_LDFLAGS) -o $@ $< $(LDLIBS)

clean:
	rm -f -- activity-sampler
