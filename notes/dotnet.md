# how to setup roslyn_ls (mac os)
1. enable rosetta which allows apple Silicon to run intel based apps
`softwareupdate --install-rosetta --agree-to-license`

2. install x64 .net runtime 
```
curl -sSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
bash /tmp/dotnet-install.sh --channel 9.0 --runtime dotnet --architecture x64 --install-dir "$HOME/.dotnet/x64"
```
3. install the sdk via brew (way easier & no conflicts)
brew install dotnet-sdk

4. download the nuget package from source netrual only!!!
[mac](https://dev.azure.com/azure-public/vside/_artifacts/feed/vs-impl/NuGet/Microsoft.CodeAnalysis.LanguageServer.osx-x64/overview)
[linux](https://dev.azure.com/azure-public/vside/_artifacts/feed/vs-impl/NuGet/Microsoft.CodeAnalysis.LanguageServer.linux-x64/overview)
instructions from `:help lspconfig-all`
Go to `https://dev.azure.com/azure-public/vside/_artifacts/feed/vs-impl/NuGet/Microsoft.CodeAnalysis.LanguageServer.<platform>/overview`
replace `<platform>` with one of the following `linux-x64`, `osx-x64`, `win-x64`, `neutral` (for more info on the download location see https://github.com/dotnet/roslyn/issues/71474#issuecomment-2177303207).

5. unzip the nuget package
```
mkdir -p ~/.local/share/roslyn-ls && \ 
cd ~/.local/share/roslyn-ls && \
unzip ~/Downloads/Microsoft.CodeAnalysis.LanguageServer.osx-x64.*.nupkg -d .
```

6. make exe executable (very macy)
    -  check if quarantined
        `xattr -l ~/.local/share/roslyn-ls/content/LanguageServer/osx-x64/Microsoft.CodeAnalysis.LanguageServer`
    - remove quarantine
        `xattr -dr com.apple.quarantine ~/.local/share/roslyn-ls`
    - chmod it my guy
        `chmod +x ~/.local/share/roslyn-ls/content/LanguageServer/osx-x64/Microsoft.CodeAnalysis.LanguageServer`
    - try a launch
        `~/.local/share/roslyn-ls/content/LanguageServer/osx-x64/Microsoft.CodeAnalysis.LanguageServer --version `

