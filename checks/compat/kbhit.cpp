#include "compat/kbhit.h"

#if !HAS_CONIO_KBHIT
    #include <stdio.h>
    #include <sys/select.h>
    #include <sys/ioctl.h>
    #include <termios.h>
    #include <unistd.h>
    #include <stropts.h>

    int kbhit() {
        static const int STDIN = 0;
        static char initialized = 0;

        if (!initialized) {
            // Use termios to turn off line buffering
            struct termios term;
            tcgetattr(STDIN, &term);
            term.c_lflag &= ~ICANON;
            tcsetattr(STDIN, TCSANOW, &term);
            setbuf(stdin, NULL);
            initialized = 1;
        }

        int bytesWaiting;
        ioctl(STDIN, FIONREAD, &bytesWaiting);
        return bytesWaiting;
    }
#endif
