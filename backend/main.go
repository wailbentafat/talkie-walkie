package main

import (
	"log"
	"net/http"
	"os"

	"github.com/go-audio/audio"
	"github.com/go-audio/wav"
	"github.com/gorilla/websocket"
)

var client = make(map[*websocket.Conn]bool)
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true
	},
}

var broadcast = make(chan []byte)

var logger = log.New(log.Writer(), "ws-server: ", log.LstdFlags|log.Lshortfile)

func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		logger.Printf("Request: %s %s", r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
	})
}

func handleConnection(w http.ResponseWriter, r *http.Request) {
	ws, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("WebSocket Upgrade Error:", err)
		return
	}
	client[ws] = true
	defer ws.Close()

	// Create a file to save the received audio
	audioFile, err := os.Create("received_audio.wav")
	if err != nil {
		log.Println("File Creation Error:", err)
		return
	}
	defer audioFile.Close()

	// Setup WAV writer
	enc := wav.NewEncoder(audioFile, 16000, 16, 1, 1) // 16kHz, 16-bit PCM, mono
	defer enc.Close()

	for {
		_, audioData, err := ws.ReadMessage()
		if err != nil {
			log.Println("Read Error:", err)
			delete(client, ws)
			break
		}

		// Log the raw audio data received
		log.Println("Received Audio Data:", len(audioData), "bytes")

		// Convert bytes to int16 PCM format and write to WAV
		int16Buffer := make([]int, len(audioData)/2)
		for i := 0; i < len(audioData); i += 2 {
			int16Buffer[i/2] = int(int16(audioData[i]) | int16(audioData[i+1])<<8)
		}

		buf := &audio.IntBuffer{Data: int16Buffer, Format: &audio.Format{SampleRate: 16000, NumChannels: 1}}
		if err := enc.Write(buf); err != nil {
			log.Println("Error Writing WAV:", err)
		}
	}
}

	
func handleMessages() {
    for {
        msg := <-broadcast
        for clien := range client {
			print("client",clien)
            err := clien.WriteMessage(websocket.BinaryMessage, msg)
            if err != nil {
                clien.Close()
                delete(client, clien)
            }
        }
    }
}


func main(){
	http.Handle("/ws",loggingMiddleware(http.HandlerFunc(handleConnection)))
	go handleMessages()
	log.Println("Server started on 192.168.1.163:8080")
     http.ListenAndServe("192.168.1.163:8080", nil)

}

