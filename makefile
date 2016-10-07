CFLAGS= /EHsc /W4 /nologo

all: miftext.exe

miftext.exe: miftext.cpp
	cl $(CFLAGS) miftext.cpp

hello2.exe: hello2.cpp
	cl $(CFLAGS) hello2.cpp

hello3.exe: hello3.cpp
	cl $(CFLAGS) hello3.cpp

hello4.exe: hello4.cpp
	cl $(CFLAGS) hello4.cpp

