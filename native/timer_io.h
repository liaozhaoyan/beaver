//
// Created by 廖肇燕 on 2024/1/14.
//

#ifndef BEAVER_TIMER_IO_H
#define BEAVER_TIMER_IO_H

// only for master timer controller

int timer_io_init(void);
unsigned long timer_io_now();
unsigned long time_io_calc(unsigned long offset);
int timer_io_set(int fd, unsigned long ms);
int timer_io_get(int fd);

#endif //BEAVER_TIMER_IO_H
