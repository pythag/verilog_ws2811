#include <stdio.h>

int main(void) {
    int i;

    for(i=0;i<256;i++) {
        if (i<85) {
            printf("%02x%02x%02x\n",i*3, 0, 255-(i*3)); // Red rising, green zero, blue falling
        } else {
            if (i<170) {
                printf("%02x%02x%02x\n",255-((i-85)*3), (i-85)*3, 0 ); // Red falling, green rising, blue zero
            } else {
                printf("%02x%02x%02x\n", 0,  255-((i-170)*3)  , (i-170)*3); // Red zero, green falling, blue rising
            }
        }
    }
}