#!/bin/bash

GREEN='\033[0;32m'
RED='\033[0;31m'
PINK='\033[0;35m'
GREY='\033[1;90m'
YELLOW='\033[1;33m' 
NC='\033[0m'

vault_file=$4
vault_secret=$5

checkIfVaultExists(){
if [ ! -f "$vault_file" ]; then
  echo -e "${RED}The Vault file ${YELLOW}$vault_file ${RED}does not exist.${NC}"
  exit 1
  else 
  echo -e "${GREY}The Vault file ${YELLOW}$vault_file ${GREY}exists.${NC}"
fi
}

createTemporaryAccessFile(){
PASS_FILE=$(mktemp)
echo "$vault_secret" > "$PASS_FILE"
echo -e "${GREY}Temporary access file: ${YELLOW}$PASS_FILE${NC}"
chmod 600 "$PASS_FILE"
}

openVault(){
if ansible-vault edit --vault-password-file="$PASS_FILE" "$vault_file"; then
  echo -e "${GREY}The Vault file ${YELLOW}$vault_file ${GREY}was successfully opened.${NC}" 
else
  echo -e "${RED}The Vault file ${YELLOW}$vault_file ${RED}could not be opened.${NC}"
fi
}

deleteTemporaryAccessFile(){
rm -f "$PASS_FILE"
if [ $? -eq 0 ]; then
  echo -e "${GREY}The temporary access file ${YELLOW}$PASS_FILE ${GREY}was successfully deleted.${NC}"
else
  echo -e "${RED}The temporary access file ${YELLOW}$PASS_FILE ${RED}could not be deleted.${NC}"
  exit 1
fi
}

methods=(
checkIfVaultExists
createTemporaryAccessFile
openVault
deleteTemporaryAccessFile
)

for method in "${methods[@]}"; do
echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
$method 
done
