#!/bin/bash

source ./config.sh

GREEN='\e[32m'
YELLOW='\e[33m'
RED='\e[31m'
NC='\e[0m'

input_deb="$build"
out="$repo"
gpg_key_id=""

if [[ -z "$suite" || -z "$component" || -z "$build" || -z "$repo" ]]; then
    echo -e "${RED}suite, component, build, atau repo tidak diset di config.sh. Exiting.${NC}"
    exit 1
fi

get_pool_path() {
    local pkg_name=$1
    local first_char="${pkg_name:0:1}"

    if [[ "$pkg_name" =~ ^lib ]]; then
        local second_char="${pkg_name:3:1}"
        echo "pool/main/lib${second_char}/${pkg_name}"
    elif [[ "$first_char" =~ [0-9] ]]; then
        echo "pool/main/${first_char}/${pkg_name}"
    else
        echo "pool/main/${first_char}/${pkg_name}"
    fi
}

echo -e "${YELLOW}Do you want to enable GPG signing? (Y/n):${NC} \c"
read -r gpg_choice
gpg_choice=${gpg_choice,,}

if [[ "$gpg_choice" == "y" || -z "$gpg_choice" ]]; then
    echo -e "${YELLOW}Do you want to import an existing GPG key? (Y/n):${NC} \c"
    read -r import_choice
    import_choice=${import_choice,,}

    if [[ "$import_choice" == "y" || -z "$import_choice" ]]; then
        echo -e "${YELLOW}Enter path to the public key file:${NC} \c"
        read -r pubkey_path
        if [[ -f "$pubkey_path" ]]; then
            gpg --import "$pubkey_path"
            echo -e "${GREEN}GPG public key imported successfully.${NC}"
            public_key_path="$(readlink -f "$pubkey_path")"
        else
            echo -e "${RED}File not found: $pubkey_path${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Launching GPG key generation wizard...${NC}"
        gpg --full-generate-key

        gpg_key_id=$(gpg --list-secret-keys --with-colons | grep '^sec' | head -n1 | cut -d':' -f5)
        if [[ -z "$gpg_key_id" ]]; then
            echo -e "${RED}No secret GPG key found. Exiting.${NC}"
            exit 1
        fi
        gpg --export -a "$gpg_key_id" > public.key
        public_key_path="$(pwd)/public.key"
        echo -e "${GREEN}GPG key ID $gpg_key_id ready for signing.${NC}"
    fi

    gpg_key_id=$(gpg --list-secret-keys --with-colons | grep '^sec' | head -n1 | cut -d':' -f5)
    if [[ -z "$gpg_key_id" ]]; then
        echo -e "${RED}No secret GPG key found. Exiting.${NC}"
        exit 1
    fi

    gpg --export -a "$gpg_key_id" > public.key
    public_key_path="$(pwd)/public.key"
    echo -e "${GREEN}GPG key ID $gpg_key_id ready for signing.${NC}"
else
    echo -e "${YELLOW}GPG signing disabled, proceeding without signing...${NC}"
fi

echo -e "${YELLOW}Cleaning old repo directory...${NC}"
rm -rf "$out"
mkdir -p "$out/dists/$suite/$component"
declare -A unique_packages

for arch_item in "${arch[@]}"; do
    mkdir -p "$out/dists/$suite/$component/binary-$arch_item"
done

mkdir -p "$input_deb"

for arch_item in "${arch[@]}"; do
    echo -e "${YELLOW}Processing architecture: $arch_item${NC}"
    count=0
    for deb_file in "$input_deb"/*_"$arch_item".deb; do
        if [[ -f "$deb_file" ]]; then
            base_name=$(dpkg-deb -f "$deb_file" Package)
            pool_path=$(get_pool_path "$base_name")
            target_dir="$out/$pool_path"
            mkdir -p "$target_dir"
            cp "$deb_file" "$target_dir/"
            unique_packages["$base_name"]=1
            ((count++))
        fi
    done
    echo -e "${GREEN}Copied $count packages for $arch_item.${NC}"
done

for arch_item in "${arch[@]}"; do
    echo -e "${YELLOW}Generating Packages for architecture: $arch_item${NC}"
    cd "$out" || exit 1
    packages_path="dists/$suite/$component/binary-$arch_item/Packages"
    mkdir -p "$(dirname "$packages_path")"
    dpkg-scanpackages -a "$arch_item" pool/main > "$packages_path"
    gzip -k -f "$packages_path"
    xz -k -f "$packages_path"
    cd - > /dev/null || exit 1
done

echo -e "${YELLOW}Generating Release file...${NC}"
cd "$out/dists/$suite" || exit 1
apt-ftparchive release . > Release

{
    echo "Suite: $suite"
    echo "Architectures: ${arch[*]}"
    echo "Components: $component"
} | cat - Release > Release.tmp && mv Release.tmp Release

if [[ -n "$gpg_key_id" ]]; then
    echo -e "${YELLOW}Signing Release file with GPG key $gpg_key_id...${NC}"
    gpg --default-key "$gpg_key_id" --clearsign -o InRelease Release
    gpg --default-key "$gpg_key_id" -abs -o Release.gpg Release
    echo -e "${GREEN}Signing completed.${NC}"

    cd "$(dirname "$public_key_path")" || exit 1

    echo -e "${YELLOW}Enter a name for the keyring (without extension):${NC} \c"
    read -r keyring_name

    if gpg --dearmor -o "$repo/${keyring_name}.gpg" "$public_key_path"; then
        echo -e "${GREEN}Keyring $keyring_name.gpg created successfully in $repo.${NC}"
    else
        echo -e "${RED}Failed to dearmor $public_key_path. Keyring not created.${NC}"
    fi

    echo -e "${YELLOW}Do you want to install the keyring to /usr/share/keyrings/${keyring_name}.gpg? (Y/n):${NC} \c"
    read -r install_keyring_choice
    install_keyring_choice=${install_keyring_choice,,}

    if [[ "$install_keyring_choice" == "y" || -z "$install_keyring_choice" ]]; then
        if sudo cp "$repo/${keyring_name}.gpg" "/usr/share/keyrings/${keyring_name}.gpg"; then
            echo -e "${GREEN}Keyring installed to /usr/share/keyrings/${keyring_name}.gpg successfully.${NC}"
            installed=true
        else
            echo -e "${RED}Failed to install keyring to /usr/share/keyrings/${keyring_name}.gpg.${NC}"
            installed=false
        fi
    else
        echo -e "${YELLOW}Skipping keyring installation.${NC}"
        installed=false
    fi
else
    installed=false
fi

cd ../../ || exit 1
echo "${#unique_packages[@]}" > "total_packages"

echo -e "\n${GREEN}Build successfully completed!${NC}\n"

echo -e "${YELLOW}Repository usage examples:${NC}\n"

echo "1) Without keyring (trusted=true):"
echo "deb [trusted=true] https://<YOUR-REPO-LINK>/ $suite $component"
echo -e "\nExample:"
echo "deb [trusted=true] https://myrepo.example.com/ $suite $component"

if [[ -n "$gpg_key_id" ]]; then
    echo -e "\n2) Using keyring without installing (signed-by):"
    echo "deb [signed-by=/usr/share/keyrings/${keyring_name}.gpg] https://<YOUR-REPO-LINK>/ $suite $component"
    echo -e "\nExample:"
    echo "deb [signed-by=/usr/share/keyrings/${keyring_name}.gpg] https://myrepo.example.com/ $suite $component"
fi

if [[ "$installed" = true ]]; then
    echo -e "\n3) Using keyring installed to /usr/share/keyrings/:"
    echo "deb [signed-by=/usr/share/keyrings/${keyring_name}.gpg] https://<YOUR-REPO-LINK>/ $suite $component"
    echo -e "\nExample:"
    echo "deb [signed-by=/usr/share/keyrings/${keyring_name}.gpg] https://myrepo.example.com/ $suite $component"
fi

