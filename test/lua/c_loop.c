#include <stdio.h>
#include <stdlib.h>

long a = 1;

long func(long b) {
   a = a + b;
   return a;
}

int main(void) {
    long i;
    for (i = 0; i < 100000000; i ++) {
        func(i);
    }
    printf("ok\n");
    return 0;
}

// use 0m0.355s