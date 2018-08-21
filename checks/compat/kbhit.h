#include "config.h"

#if HAS_CONIO_KHBIT
    #include <conio.h>
#else
    int kbhit();
#endif
