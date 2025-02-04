package main

import (
	
	"log"
	"net/http"

	"github.com/gorilla/websocket"
)
var client =make(map[*websocket.Conn]bool)
var upgrader =websocket.Upgrader{
	ReadBufferSize:1024,
	WriteBufferSize:1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},

}
var broadcast =make(chan []byte)	

func handleconnection(h http.ResponseWriter, r *http.Request){
	ws,err:=upgrader.Upgrade(h,r,nil)
	if err != nil {
		log.Printf("%v",err)
	}
	client[ws]=true

    defer ws.Close()

	 for {
	messagetype,mess,err:=ws.ReadMessage()
	if err != nil {
		log.Println(err)
		delete(client,ws)
		
	}
	broadcast <- mess
	log.Println(string(mess))
	log.Println("message type",messagetype)
 
	
	 }
	 

	
}
func handleMessages() {
    for {
        msg := <-broadcast
        for clien := range client {
            err := clien.WriteMessage(websocket.BinaryMessage, msg)
            if err != nil {
                clien.Close()
                delete(client, clien)
            }
        }
    }
}


func main(){
	http.HandleFunc("/ws",handleconnection)
	go handleMessages()
	log.Println("server started")
	http.ListenAndServe(":8080",nil)

}
