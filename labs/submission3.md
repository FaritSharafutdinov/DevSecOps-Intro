## Task 1: SSH Commit Signing
- **Benefits**: Подпись коммитов подтверждает, что автором изменений действительно являюсь я, предотвращая подделку коммитов в DevSecOps пайплайнах.
- **Configuration**: Выполнил генерацию ключа ed25519 и настроил `git config gpg.format ssh`.
- **Verification**: ![photo_2026-02-22_19-31-28](https://github.com/user-attachments/assets/8fd056e8-7999-4ba6-aa22-3e07fb4a580a)


## Task 2: Pre-commit Secret Scanning
- **Setup**: Настроен локальный хук в `.git/hooks/pre-commit`, использующий TruffleHog и Gitleaks.
- **Testing**: Попытка закоммитить AWS ключ была заблокирована сканером (см. скриншот).
- **Screenshot**: ![photo_2026-02-22_19-31-34](https://github.com/user-attachments/assets/c44b5f48-8060-44fe-83e9-801ea1c438cf)
- **Analysis**: Автоматическое сканирование на уровне pre-commit предотвращает попадание секретов в удаленный репозиторий, минимизируя риск компрометации инфраструктуры.
