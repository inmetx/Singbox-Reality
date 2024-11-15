# Singbox-Reality

Singbox-Reality 是第一个以sing-box 内核一键安装 REALITY 的脚本！

## 功能

- 易于安装和配置
- 可选择所需的端口和 SNI

## 先决条件

- Linux 操作系统
- Bash shell


## 使用方法

要使用 Singbox-Reality，只需在 Linux 机器上执行以下命令即可：
此外，强烈建议更新软件源（apt update && apt upgrade）。
- 本脚本使用 JQ，它会自动安装
- 本脚本使用 443 作为默认端口号。
- 本脚本使用 “addons.mozilla.org ”作为 SNI。当脚本要求您更改时，请将其更改为您想要的 SNI。


```bash
bash <(curl -fsSL https://github.com/inmetx/Singbox-Reality/raw/main/Singbox-Reality.sh)
```

