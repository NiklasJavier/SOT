#!/usr/bin/env bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PINK='\033[0;35m'
GREY='\033[1;90m'
NC='\033[0m' 

clone_dir="$7"
branch="${10}"

gitOpenLocalRepository() {
  echo -e "${GREY}Current branch: ${YELLOW}$branch${NC}"
  echo -e "${GREY}Current directory: ${YELLOW}$clone_dir${NC}"
  cd "$clone_dir" || { echo -e "${GREY}Error: Could not find the directory $clone_dir."; exit 1; }
}

gitFetchAddedContent() {
  echo -e "${GREY}Fetching added content.${NC}"
  echo -e "${YELLOW}>> GIT FETCH <<"
  git fetch
}

gitPullNewContentFromBranch() {
  echo -e "${GREY}Pulling new content from branch.${NC}"
  echo -e "${YELLOW}>> GIT PULL --REBASE --AUTOSTASH <<${NC}"
  git pull --rebase --autostash
  echo -e "${YELLOW}Successfully pulled new content from branch.${NC}"
}

methods=(
gitOpenLocalRepository
gitFetchAddedContent
gitPullNewContentFromBranch
)

for method in "${methods[@]}"; do
echo -e "\n${GREY}======= ${GREEN}Running: ${PINK}[$method] ${GREY}=======${NC}"
$method 
done
