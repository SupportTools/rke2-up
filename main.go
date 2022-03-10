package main

import (
	"bytes"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"os/exec"

	"github.com/Sirupsen/logrus"
	"github.com/reenjii/logflag"
	"gopkg.in/yaml.v2"
)

var command string

type Config struct {
	Master []struct {
		Host      string `yaml:"host"`
		IP        string `yaml:"ip"`
		Port      int    `yaml:"port"`
		Privateip string `yaml:"privateip,omitempty"`
		Publicip  string `yaml:"publicip,omitempty"`
		User      string `yaml:"user,omitempty"`
		Key       string `yaml:"key,omitempty"`
		NodeTaint []struct {
			Taint string `yaml:"taint"`
		} `yaml:"node-taint,omitempty"`
	} `yaml:"master"`
	Worker []struct {
		Host      string `yaml:"host"`
		IP        string `yaml:"ip"`
		Port      int    `yaml:"port"`
		Privateip string `yaml:"privateip,omitempty"`
		Publicip  string `yaml:"publicip,omitempty"`
		User      string `yaml:"user,omitempty"`
		Key       string `yaml:"key,omitempty"`
		NodeTaint []struct {
			Taint string `yaml:"taint"`
		} `yaml:"node-taint,omitempty"`
	} `yaml:"worker"`
	Global struct {
		SSH struct {
			User                  string `yaml:"user"`
			Key                   string `yaml:"key"`
			Timeout               int    `yaml:"timeout"`
			Port                  int    `yaml:"port"`
			StrictHostKeyChecking string `yaml:"strict-host-key-checking"`
		} `yaml:"ssh"`
		Rke2 struct {
			Version string   `yaml:"version"`
			TLSSan  []string `yaml:"tls-san"`
		} `yaml:"rke2"`
	} `yaml:"global"`
}

func NewConfig(configPath string) (*Config, error) {
	config := &Config{}
	file, err := ioutil.ReadFile(configPath)
	if err != nil {
		return nil, err
	}
	err = yaml.Unmarshal(file, config)
	if err != nil {
		panic(err)
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
	logrus.Debug("Global Settings")
	logrus.Debug("SSH Settings")
	logrus.Debug("SSH User: ", config.Global.SSH.User)
	logrus.Debug("SSH Key: ", config.Global.SSH.Key)
	logrus.Debug("SSH Timeout: ", config.Global.SSH.Timeout)
	logrus.Debug("SSH Port: ", config.Global.SSH.Port)
	logrus.Debug("SSH StrictHostKeyChecking: ", config.Global.SSH.StrictHostKeyChecking)
	logrus.Debug("RKE2 Settings")
	logrus.Debug("RKE2 Version: ", config.Global.Rke2.Version)
	logrus.Debug("RKE2 TLSSan: ", config.Global.Rke2.TLSSan)

	logrus.Debug("Master Nodes:")
	for _, master := range config.Master {
		logrus.Debug("Hostname: ", master.Host)
		logrus.Debug("IP: ", master.IP)
	}

	logrus.Debug("Worker Nodes:")
	for _, worker := range config.Worker {
		logrus.Debug("Hostname: ", worker.Host)
		logrus.Debug("IP: ", worker.IP)
	}

	logrus.Info("Verifying SSH connectivity to all nodes")
	command = "echo 'SSH access OK'"
	for _, master := range config.Master {
		if _, err := RunSSH(master.IP, master.Key, master.User, master.Port, config, command); err != nil {
			log.Fatalf("SSH access to %s failed: %s", master.IP, err)
		} else {
			logrus.Info("SSH access to ", master.IP, " was Successful")
		}
	}
	for _, worker := range config.Worker {
		if _, err := RunSSH(worker.IP, worker.Key, worker.User, worker.Port, config, command); err != nil {
			log.Fatalf("SSH access to %s failed: %s", worker.IP, err)
		} else {
			logrus.Info("SSH access to ", worker.IP, " was Successful")
		}
	}

	logrus.Info("Installing RKE2 on all master nodes...")
	rke2Type := "server"
	if config.Global.Rke2.Version == "" {
		logrus.Debug("RKE2 Version is not set, defaulting to latest")
		command = fmt.Sprintf("curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=%s sh -", rke2Type)
	} else {
		logrus.Debug("RKE2 Version is set to: ", config.Global.Rke2.Version)
		command = fmt.Sprintf("curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=%s INSTALL_RKE2_TYPE=%s sh -", config.Global.Rke2.Version, rke2Type)
	}
	for _, master := range config.Master {
		if _, err := RunSSH(master.IP, master.Key, master.User, master.Port, config, command); err != nil {
			log.Fatalf("RKE2 install failed on %s with error %s", master.IP, err)
		} else {
			logrus.Info("RKE2 install on ", master.IP, " was Successful")
		}
	}

	logrus.Info("Installing RKE2 on all worker nodes...")
	if config.Global.Rke2.Version == "" {
		logrus.Debug("RKE2 Version is not set, defaulting to latest")
		command = fmt.Sprintf("curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE=agent sh -")
	} else {
		command = fmt.Sprintf("curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION=%s INSTALL_RKE2_TYPE=agent sh -", config.Global.Rke2.Version)
	}
	for _, master := range config.Master {
		if _, err := RunSSH(master.IP, master.Key, master.User, master.Port, config, command); err != nil {
			log.Fatalf("RKE2 install failed on %s with error %s", master.IP, err)
		} else {
			logrus.Info("RKE2 install on ", master.IP, " was Successful")
		}
	}

	logrus.Info("Detecting if RKE2 cluster is already created or will it need to be bootstrapped...")
	command = "cat /var/lib/rancher/rke2/server/token"
	var token string
	for _, master := range config.Master {
		tokenCandidate, err := RunSSH(master.IP, master.Key, master.User, master.Port, config, command)
		if err != nil {
			log.Fatalf("RKE2 cluster detection failed on %s with error %s", master.IP, err)
		} else {
			logrus.Info("RKE2 cluster detection on ", master.IP, " was Successful")
		}
		logrus.Debug("Token Candidate: ", tokenCandidate)
		if tokenCandidate != "" {
			token = tokenCandidate
			logrus.Info("RKE2 cluster detected on ", master.IP, " with token: ", token)
		}
	}
	if token != "" {
		logrus.Info("RKE2 cluster already exists, skipping bootstrap...")
	} else {
		logrus.Info("RKE2 cluster does not exist, bootstrapping...")
	}

}

func RunSSH(ip string, key string, user string, port int, config Config, command string) (string, error) {

	if key == "" {
		key = config.Global.SSH.Key
	}
	if user == "" {
		user = config.Global.SSH.User
	}
	if port == 0 {
		port = config.Global.SSH.Port
	}

	logrus.Debug("IP: ", ip)
	logrus.Debug("Key: ", key)
	logrus.Debug("User: ", user)
	logrus.Debug("Port: ", port)

	cmd := exec.Command("ssh", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-i", key, user+"@"+ip, command)
	var out bytes.Buffer
	logrus.Debug("Executing: ", cmd)
	logrus.Debug("Output: ", out)
	cmd.Stdout = &out
	err := cmd.Run()
	if err != nil {
		log.Fatal(err)
	}
	return out.String(), err
}

func main() {
	flag.Parse()
	logflag.Parse()

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
