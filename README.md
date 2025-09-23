# S3 Prefix Protection System / S3前缀保护系统

[English](#english) | [中文](#中文)

---

## English

### Overview

The S3 Prefix Protection System is an automated AWS solution that applies Legal Hold protection to S3 objects based on configurable prefixes. When objects are uploaded to specified prefixes in your S3 bucket, the system automatically applies Legal Hold to prevent accidental deletion or modification.

### Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   S3 Bucket     │    │   SQS Queue     │    │ Lambda Function │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ Object      │ │───▶│ │ S3 Event    │ │───▶│ │ Process &   │ │
│ │ Upload      │ │    │ │ Message     │ │    │ │ Apply Legal │ │
│ │ (Prefix     │ │    │ │             │ │    │ │ Hold        │ │
│ │ Match)      │ │    │ └─────────────┘ │    │ └─────────────┘ │
│ └─────────────┘ │    │                 │    │                 │
│                 │    │ ┌─────────────┐ │    └─────────────────┘
│ • Versioning    │    │ │ Dead Letter │ │             │
│ • Object Lock   │    │ │ Queue (DLQ) │ │             │
│ • Event Notify  │    │ │             │ │             ▼
└─────────────────┘    │ └─────────────┘ │    ┌─────────────────┐
                       └─────────────────┘    │   CloudWatch    │
                                              │                 │
                                              │ • Logs          │
                                              │ • Metrics       │
                                              │ • Alarms        │
                                              └─────────────────┘
```

### Key Features

- **Automated Protection**: Automatically applies S3 Object Lock Legal Hold to objects matching specified prefixes
- **Event-Driven Architecture**: Uses S3 event notifications and SQS for reliable processing
- **Retry Mechanism**: Built-in retry logic with exponential backoff for robust operation
- **Monitoring & Alerting**: CloudWatch alarms for failed processing and dead letter queue monitoring
- **Easy Deployment**: Single-command deployment using CloudFormation
- **Configurable**: Customizable prefixes, Lambda settings, and lifecycle policies

### Architecture Components

- **S3 Bucket**: Source bucket with versioning and Object Lock enabled
- **Lambda Function**: Processes S3 events and applies Legal Hold protection
- **SQS Queue**: Reliable message processing with dead letter queue for failed messages
- **CloudWatch**: Monitoring, logging, and alerting
- **IAM Roles**: Least-privilege access for secure operations

### Prerequisites

- AWS CLI configured with appropriate permissions
- S3 bucket with versioning enabled (will be configured automatically if needed)
- Object Lock enabled on the bucket (will be configured automatically if needed)

### Quick Start

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd s3-prefix-protection
   ```

2. **Deploy the system**
   ```bash
   ./deploy.sh my-protection-stack my-bucket-name "important/,backup/,archive/" us-east-1 60
   ```

   Parameters:
   - `stack-name`: CloudFormation stack name
   - `bucket-name`: Target S3 bucket name
   - `protected-prefixes`: Comma-separated list of prefixes to protect
   - `region`: AWS region
   - `lifecycle-days`: (Optional) Reference days for lifecycle policy (default: 60)

### Usage Examples

**Protect specific folders:**
```bash
./deploy.sh prod-protection my-prod-bucket "critical/,backups/,logs/" us-west-2
```

**Test the protection:**
```bash
# Upload a test file
echo "Test content" > test.txt
aws s3 cp test.txt s3://my-bucket/important/test.txt

# Check Legal Hold status
aws s3api get-object-legal-hold --bucket my-bucket --key important/test.txt
```

### Monitoring

**View processing logs:**
```bash
aws logs tail /aws/lambda/my-bucket-object-processor --follow
```

**Check for failed messages:**
```bash
aws sqs receive-message --queue-url <dead-letter-queue-url>
```

### Configuration

The system supports the following configuration options:

- **Protected Prefixes**: Define which object prefixes should be protected
- **Lambda Memory**: Adjust memory allocation (128MB - 3008MB)
- **Lambda Timeout**: Set processing timeout (1-900 seconds)
- **Lifecycle Days**: Configure lifecycle policy reference

### Security

- Uses least-privilege IAM roles
- Encrypted SQS queues
- CloudWatch logging for audit trails
- No hardcoded credentials

### Cleanup

To remove the protection system:
```bash
aws cloudformation delete-stack --stack-name my-protection-stack --region us-east-1
```

---

## 中文

### 概述

S3前缀保护系统是一个自动化的AWS解决方案，基于可配置的前缀为S3对象应用Legal Hold保护。当对象上传到S3存储桶中的指定前缀时，系统会自动应用Legal Hold以防止意外删除或修改。

### 架构图

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   S3存储桶      │    │   SQS队列       │    │ Lambda函数      │
│                 │    │                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ 对象上传    │ │───▶│ │ S3事件      │ │───▶│ │ 处理并应用  │ │
│ │ (前缀匹配)  │ │    │ │ 消息        │ │    │ │ Legal Hold  │ │
│ │             │ │    │ │             │ │    │ │             │ │
│ │             │ │    │ └─────────────┘ │    │ └─────────────┘ │
│ └─────────────┘ │    │                 │    │                 │
│                 │    │ ┌─────────────┐ │    └─────────────────┘
│ • 版本控制      │    │ │ 死信队列    │ │             │
│ • 对象锁定      │    │ │ (DLQ)       │ │             │
│ • 事件通知      │    │ │             │ │             ▼
└─────────────────┘    │ └─────────────┘ │    ┌─────────────────┐
                       └─────────────────┘    │   CloudWatch    │
                                              │                 │
                                              │ • 日志          │
                                              │ • 指标          │
                                              │ • 告警          │
                                              └─────────────────┘
```

### 核心功能

- **自动化保护**: 自动为匹配指定前缀的对象应用S3 Object Lock Legal Hold
- **事件驱动架构**: 使用S3事件通知和SQS进行可靠处理
- **重试机制**: 内置指数退避重试逻辑，确保操作稳定性
- **监控告警**: CloudWatch告警监控处理失败和死信队列
- **简易部署**: 使用CloudFormation单命令部署
- **可配置**: 可自定义前缀、Lambda设置和生命周期策略

### 架构组件

- **S3存储桶**: 启用版本控制和Object Lock的源存储桶
- **Lambda函数**: 处理S3事件并应用Legal Hold保护
- **SQS队列**: 可靠的消息处理，包含失败消息的死信队列
- **CloudWatch**: 监控、日志记录和告警
- **IAM角色**: 最小权限访问，确保安全操作

### 前置条件

- 配置了适当权限的AWS CLI
- 启用版本控制的S3存储桶（如需要会自动配置）
- 存储桶上启用Object Lock（如需要会自动配置）

### 快速开始

1. **克隆仓库**
   ```bash
   git clone <repository-url>
   cd s3-prefix-protection
   ```

2. **部署系统**
   ```bash
   ./deploy.sh my-protection-stack my-bucket-name "important/,backup/,archive/" us-east-1 60
   ```

   参数说明:
   - `stack-name`: CloudFormation堆栈名称
   - `bucket-name`: 目标S3存储桶名称
   - `protected-prefixes`: 要保护的前缀列表（逗号分隔）
   - `region`: AWS区域
   - `lifecycle-days`: （可选）生命周期策略参考天数（默认：60）

### 使用示例

**保护特定文件夹:**
```bash
./deploy.sh prod-protection my-prod-bucket "critical/,backups/,logs/" us-west-2
```

**测试保护功能:**
```bash
# 上传测试文件
echo "测试内容" > test.txt
aws s3 cp test.txt s3://my-bucket/important/test.txt

# 检查Legal Hold状态
aws s3api get-object-legal-hold --bucket my-bucket --key important/test.txt
```

### 监控

**查看处理日志:**
```bash
aws logs tail /aws/lambda/my-bucket-object-processor --follow
```

**检查失败消息:**
```bash
aws sqs receive-message --queue-url <dead-letter-queue-url>
```

### 配置选项

系统支持以下配置选项：

- **保护前缀**: 定义哪些对象前缀应该被保护
- **Lambda内存**: 调整内存分配（128MB - 3008MB）
- **Lambda超时**: 设置处理超时时间（1-900秒）
- **生命周期天数**: 配置生命周期策略参考

### 安全性

- 使用最小权限IAM角色
- 加密的SQS队列
- CloudWatch日志记录用于审计跟踪
- 无硬编码凭证

### 清理

删除保护系统:
```bash
aws cloudformation delete-stack --stack-name my-protection-stack --region us-east-1
```

### 故障排除

**常见问题:**

1. **存储桶版本控制未启用**
   - 部署脚本会自动检测并提示启用

2. **Object Lock未启用**
   - 部署脚本会自动检测并提示启用

3. **权限不足**
   - 确保AWS CLI配置了足够的权限

4. **Lambda函数超时**
   - 调整Lambda超时设置或内存分配

**日志位置:**
- Lambda函数日志: `/aws/lambda/{bucket-name}-object-processor`
- S3通知配置日志: `/aws/lambda/{bucket-name}-s3-notification-config`
