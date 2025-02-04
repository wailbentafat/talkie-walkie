package main

import (
	"log"
	"net/http"
	"os"

	"github.com/go-audio/audio"
	"github.com/go-audio/wav"
	"github.com/gorilla/websocket"
)


var clients = make(map[*websocket.Conn]bool)
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}


var logger = log.New(os.Stdout, "WS-SERVER: ", log.LstdFlags|log.Lshortfile)


var broadcast = make(chan []byte)


// func handleConnection(w http.ResponseWriter, r *http.Request) {
// 	ws, err := upgrader.Upgrade(w, r, nil)
// 	if err != nil {
// 		logger.Println("WebSocket Upgrade Error:", err)
// 		return
// 	}
// 	clients[ws] = true
// 	defer ws.Close()

// 	logger.Println("Client Connected")

// 	for {
// 		_, audioData, err := ws.ReadMessage()
// 		if err != nil {
// 			logger.Println("Read Error:", err)
// 			delete(clients, ws)
// 			break
// 		}

		
// 		if len(audioData) == 0 {
// 			logger.Println("Received empty audio data!")
// 			continue
// 		}
// 		logger.Printf("Received audio: %d bytes\n", len(audioData))

		
// 		err = saveWavFile(audioData, "received_audio.wav")
// 		if err != nil {
// 			logger.Println("Error saving WAV file:", err)
// 		}
// 		broadcast <- audioData
// 	}
	
// }
func handleConnection(w http.ResponseWriter, r *http.Request) {
    ws, err := upgrader.Upgrade(w, r, nil)
    if err != nil {
        logger.Println("WebSocket Upgrade Error:", err)
        return
    }
    clients[ws] = true
    defer func() {
        delete(clients, ws)
        ws.Close()
    }()

    logger.Println("Client Connected")

    for {
        _, audioChunk, err := ws.ReadMessage()
        if err != nil {
            logger.Println("Read Error:", err)
            delete(clients, ws)
            break
        }

        if len(audioChunk) == 0 {
            logger.Println("Received empty chunk!")
            continue
        }

        logger.Printf("Received audio chunk: %d bytes\n", len(audioChunk))

       
        for client := range clients {
            if err := client.WriteMessage(websocket.BinaryMessage, audioChunk); err != nil {
                client.Close()
                delete(clients, client)
            }
			logger.Println("Audio chunk sent to all clients", len(audioChunk))
        }
    }
}


func saveWavFile(data []byte, filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	
	enc := wav.NewEncoder(file, 16000, 16, 1, 1) 

	
	int16Buffer := make([]int, len(data)/2)
	for i := 0; i < len(data); i += 2 {
		int16Buffer[i/2] = int(int16(data[i]) | int16(data[i+1])<<8)
	}

	
	buf := &audio.IntBuffer{
		Data:           int16Buffer,
		Format:         &audio.Format{SampleRate: 16000, NumChannels: 1},
		SourceBitDepth: 16,
	}

	
	err = enc.Write(buf)
	if err != nil {
		return err
	}

	return enc.Close()
}


func handleMessages() {
	for {
		msg := <-broadcast
		for client := range clients {
			err := client.WriteMessage(websocket.BinaryMessage, msg)
			if err != nil {
				client.Close()
				delete(clients, client)
			}
		}
	}
}


func main() {
	http.Handle("/ws", http.HandlerFunc(handleConnection))
	go handleMessages()
	logger.Println("Server started on 192.168.1.163:8080")
	http.ListenAndServe("192.168.1.163:8080", nil)
}
