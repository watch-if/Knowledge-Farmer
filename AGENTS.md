# Knowledge-Farmer 项目协作

用户要求每次项目更新同步 GitHub。代码和资源经过相应验证后，提交本轮改动并常规推送到 `watch-if/Knowledge-Farmer` 的 `main`。保留远程已有提交，避免强制推送。

`main` 的每次推送触发 Windows 与 Android 联发流程。等待 GitHub Actions 完成并核对同一 Release 里的两个附件，再汇报下载链接。构建缓存保留在本地。
