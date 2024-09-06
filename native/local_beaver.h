//
// Created by 廖肇燕 on 2023/2/14.
//

#ifndef LOCAL_BEAVER_H
#define LOCAL_BEAVER_H

#define NATIVE_EVENT_MAX 256

typedef struct native_event {
    int fd;
    short int ev_in;
    short int ev_out;
    short int ev_close;
}native_event_t;

typedef struct native_cell {
    int fd;
    unsigned long events;
}native_cell_t;

typedef struct native_events {
    int num;
    native_cell_t evs[NATIVE_EVENT_MAX];
}native_events_t;

#endif //UNITY_LOCAL_BEAVER_H
