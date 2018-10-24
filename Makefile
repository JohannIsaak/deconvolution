CXXFLAGS=-O3 -Wall -Wextra -pedantic -std=c++11 #-fdiagnostics-color=auto
ROOTFLAGS=$(shell root-config --cflags)
ROOTLIB=$(shell root-config --libs)

all: unfold_minuit

unfold_minuit: unfold_minuit.cpp
	g++ $(CXXFLAGS) $(ROOTFLAGS) $< $(ROOTLIB) -o $@

clean:
	rm unfold_minuit
