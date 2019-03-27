
%.x : %.o
	ld $^ -s -o $@

%.o : %.asm
	nasm $< -felf64 -o $@

list: find.x
	./find.x .

clean:
	rm *.x
	rm *.o