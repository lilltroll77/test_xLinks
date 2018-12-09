/*
 * test_xLinks.xc
 *
 *  Created on: 9 dec 2018
 *      Author: micke
 */
// Network Topology -  Automatically computed Tree

#include "platform.h"
#include "stdio.h"
#include "xs1.h"

#define CLEN 12
#define OFFSET 0
#define PACKAGE 4

const char tileID[]="Tile rounting ID:";

interface com_if{
    void toMotherShip(int tileID , int coreID);
    [[guarded]] [[notification]] slave void notify();
    [[guarded]] [[clears_notification]] int fromMotherShip();
};


{int , int} rx(chanend c){
    int tileID , coreID;
    slave{
        c:> tileID;
        c:> coreID;
    }
    return {tileID , coreID};
}

void mothership(server interface com_if data[CLEN]){
    timer tmr;
    unsigned t;
    tmr:> t;
    while(1){
        for (int i = 0 ;i < CLEN; i++){
            select{
            case tmr when timerafter(t + 9999):> t:
                    int tile = t%CLEN;
                    printf("Notify tile%d\n" , tile);
                    data[tile].notify();
                    break;
            case data[int i].toMotherShip(int tileID , int coreID):
                    printf("Mothership recieved message from tile ID:%d Core:%d\n" , tileID-OFFSET , coreID);
                    break;
            case data[int i].fromMotherShip() ->int message :
                    message = t;
                    break;


            }
        }
    }
}

void daisy_c(chanend c){
    int tileID , coreID;
    slave{
        c:> tileID;
        c:> coreID;
    }
       printf("Tile ID:%d Core:%d recieving message from tile:%d Core:%d via a daisychained link to the mothership switch\n" ,tileID ,get_local_tile_id()-OFFSET , get_logical_core_id(), tileID-OFFSET , coreID);
}


void reciever_c(chanend c){
    int tileID , coreID;
    slave{
        c:> tileID;
        c:> coreID;
    }
    printf("Tile ID:%d Core:%d recieving message from tile ID:%d Core:%d via mothership switch\n" , get_local_tile_id()-OFFSET , get_logical_core_id(), tileID-OFFSET , coreID);



}

void sender_if(client interface com_if data , unsigned delay){
    int tileID = get_local_tile_id();
    int coreID = get_logical_core_id();
    timer tmr;
    unsigned t;
    tmr:> t;
    tmr when timerafter(t + delay):> void;
    data.toMotherShip(tileID , coreID);
    while(1){
        select{
        case data.notify():
            int message = data.fromMotherShip();
            printf("Tile ID:%d Core:%d was notified by the mothership which sent message %d\n" , tileID ,coreID,message);
            break;
        }
    }
}

void sender_c(chanend c , unsigned delay){
    timer tmr;
    unsigned t;
    tmr:> t;
    tmr when timerafter(t + delay):> void;
    master{
        c <: get_local_tile_id();
        c <: get_logical_core_id();
    }
}

int main(){


    interface com_if data[CLEN];
    chan c[CLEN];


    par{
        on tile[0]: mothership(data);

        par(int i=0; i<CLEN ; i++){
            on tile[i]: sender_if(data[i] ,1000*i);
            on tile[i]: sender_c(c[i], 3000*i);
            on tile[CLEN-1-i]: reciever_c(c[i]);
        }

    }
    return 0;
}
