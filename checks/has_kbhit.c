#include <conio.h>

int main()
{
    if (kbhit())
    {
        return 1;
    }

    return 0;
}
