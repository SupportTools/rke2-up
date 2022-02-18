package main

import (
	"bytes"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"

	"gopkg.in/yaml.v3"
)

type Config struct {
	SshKeyPath string   `yaml:"ssh_key_path",default:"~/.ssh/id_rsa"`
	SshUser    string   `yaml:"ssh_user",default:"root"`
	SshPort    string   `yaml:"ssh_port",default:"22"`
	SshTimeout string   `yaml:"ssh_timeout",default:"10"`
	SshSudo    string   `yaml:"ssh_sudo",default:"false"`
	MasterData []Master `yaml:"master"`
	WorkerData []Worker `yaml:"worker"`
}

type Master struct {
	Host string `yaml:"host"`
	Ip   string `yaml:"ip"`
}

type Worker struct {
	Host string `yaml:"host"`
	Ip   string `yaml:"ip"`
}

func NewConfig(configPath string) (*Config, error) {
	config := &Config{}
	file, err := os.Open(configPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	d := yaml.NewDecoder(file)

	if err := d.Decode(&config); err != nil {
		return nil, err
	}

	return config, nil
}

func ValidateConfigPath(path string) error {
	s, err := os.Stat(path)
	if err != nil {
		return err
	}
	if s.IsDir() {
		return fmt.Errorf("'%s' is a directory, not a normal file", path)
	}
	return nil
}

func ParseFlags() (string, error) {
	var configPath string

	flag.StringVar(&configPath, "config", "./config.yml", "path to config file")

	flag.Parse()

	if err := ValidateConfigPath(configPath); err != nil {
		return "", err
	}

	return configPath, nil
}

func (config Config) Run() {
	fmt.Println("Settings:")
	fmt.Printf("ssh_key_path: %s\n", config.SshKeyPath)
	fmt.Printf("ssh_user: %s\n", config.SshUser)
	fmt.Printf("ssh_port: %s\n", config.SshPort)
	fmt.Printf("ssh_timeout: %s\n", config.SshTimeout)
	fmt.Printf("ssh_sudo: %s\n", config.SshSudo)

	fmt.Println("Master Nodes:")
	for _, master := range config.MasterData {
		fmt.Printf("Hostname: %s\n", master.Host)
		fmt.Printf("Ip: %s\n", master.Ip)
	}

	fmt.Println("Worker Nodes:")
	for _, worker := range config.WorkerData {
		fmt.Printf("Hostname: %s\n", worker.Host)
		fmt.Printf("Ip: %s\n", worker.Ip)
	}

	fmt.Println("Verifing SSH access to all nodes...")

	for _, master := range config.MasterData {
		if err := CheckSSH(master.Ip, config); err != nil {
			log.Fatalf("SSH access to %s failed: %s", master.Ip, err)
		}
	}
	for _, worker := range config.WorkerData {
		if err := CheckSSH(worker.Ip, config); err != nil {
			log.Fatalf("SSH access to %s failed: %s", worker.Ip, err)
		}
	}

}

func CheckSSH(ip string, config Config) error {
	fmt.Printf("Checking SSH access to %s\n", ip)
	cmd := exec.Command("ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout="+config.SshTimeout, "-i", config.SshKeyPath, config.SshUser+"@"+ip, "echo 'SSH access OK'")
	var out bytes.Buffer
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Fatal(err)
	}
	fmt.Printf("%s\n", out.String())
	return err
}

func main() {
	cfgPath, err := ParseFlags()
	if err != nil {
		log.Fatal(err)
	}
	cfg, err := NewConfig(cfgPath)
	if err != nil {
		log.Fatal(err)
	}
	cfg.Run()
}
