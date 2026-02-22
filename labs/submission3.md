## Task 1: SSH Commit Signing
- **Benefits**: Подпись коммитов подтверждает, что автором изменений действительно являюсь я, предотвращая подделку коммитов в DevSecOps пайплайнах.
- **Configuration**: Выполнил генерацию ключа ed25519 и настроил `git config gpg.format ssh`.
- **Verification**: 

## Task 2: Pre-commit Secret Scanning
- **Setup**: Настроен локальный хук в `.git/hooks/pre-commit`, использующий TruffleHog и Gitleaks.
- **Testing**: Попытка закоммитить AWS ключ была заблокирована сканером (см. скриншот).
- **Screenshot**: 
- **Analysis**: Автоматическое сканирование на уровне pre-commit предотвращает попадание секретов в удаленный репозиторий, минимизируя риск компрометации инфраструктуры.