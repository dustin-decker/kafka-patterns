package main

import (
	"flag"
	"fmt"
	"log"
	"time"

	"github.com/confluentinc/confluent-kafka-go/kafka"
	"github.com/segmentio/ksuid"
)

var (
	brokers  string
	topic    string
	records  int
	tls      bool
	certFile string
	caFile   string
	keyFile  string
)

func init() {
	flag.StringVar(&brokers, "brokers", "localhost:9092", "broker addresses, comma-separated")
	flag.StringVar(&topic, "topic", "topic", "topic to consume from")
	flag.IntVar(&records, "records", 1000000, "number of records to read from kafka")
	flag.BoolVar(&tls, "tls", false, "tls enabled?")
	flag.StringVar(&certFile, "cert", "_cert.pem", "tls cert")
	flag.StringVar(&caFile, "ca", "_ca.pem", "tls ca")
	flag.StringVar(&keyFile, "key", "_key.pem", "tls key")
	flag.Parse()
}

func check(err error) {
	if err != nil {
		log.Fatalln(err)
	}
}

func main() {
	benchmark()
}

func benchmark() {
	groupID := ksuid.New().String()
	cm := &kafka.ConfigMap{
		"session.timeout.ms":              10000,
		"metadata.broker.list":            brokers,
		"enable.auto.commit":              false,
		"go.events.channel.enable":        true,
		"go.application.rebalance.enable": true,
		"group.id":                        groupID,
		"default.topic.config": kafka.ConfigMap{
			"auto.offset.reset": "newest",
		},

		"security.protocol":        "ssl",
		"ssl.ca.location":          caFile,
		"ssl.certificate.location": certFile,
		"ssl.key.location":         keyFile,
	}

	consumer, err := kafka.NewConsumer(cm)
	check(err)
	defer consumer.Close()

	check(consumer.Subscribe(topic, nil))

	var start time.Time
	count := 0

loop:
	for {
		select {
		case m, ok := <-consumer.Events():
			if !ok {
				panic("unexpected eof")
			}

			switch event := m.(type) {
			case kafka.AssignedPartitions:
				consumer.Assign(event.Partitions)

			case kafka.PartitionEOF:
				// nop

			case kafka.RevokedPartitions:
				consumer.Unassign()

			case *kafka.Message:
				count++
				if count == 1 {
					start = time.Now()
				}
				if count == records {
					break loop
				}

			default:
				panic(m)
			}
		}
	}
	elapsed := time.Now().Sub(start)
	fmt.Printf("confluent: %v records, %v\n", count, elapsed)
}
