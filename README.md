# Script PostgreSQL

Desenvolvimento de um **script SQL para PostgreSQL**, voltado à **criação, configuração e manutenção de um banco de dados relacional**.

O projeto automatiza o processo de **estruturação e atualização de tabelas**, além de configurar o ambiente para o correto funcionamento de aplicações que utilizam o banco de dados.

---

## 📚 Sumário

* [💡 Sobre o Projeto](#-sobre-o-projeto)
* [⚙️ Tecnologias Utilizadas](#️-tecnologias-utilizadas)
* [🧩 Estrutura do Projeto](#-estrutura-do-projeto)
* [🚀 Como Utilizar](#-como-utilizar)
* [👩‍💻 Autor](#-autor)

---

## 💡 Sobre o Projeto

O **Script PostgreSQL** foi desenvolvido com o objetivo de **automatizar a criação e configuração de um banco de dados PostgreSQL**, incluindo:

* Definição de **extensões** necessárias (`uuid-ossp`, entre outras).
* Criação e atualização de **tabelas de usuários, assinaturas, pagamentos e registros de log**.
* Padronização do **fuso horário** do banco de dados para `America/Sao_Paulo`.
* Estrutura pronta para uso em **aplicações web** ou **painéis analíticos**.

O script pode ser executado em qualquer instância PostgreSQL compatível (local ou em nuvem).

---

## ⚙️ Tecnologias Utilizadas

| Categoria                   | Tecnologias / Ferramentas   |
| --------------------------- | --------------------------- |
| **Banco de Dados**          | PostgreSQL 13+              |
| **Linguagem**               | SQL (PostgreSQL Dialeto)    |
| **Extensões**               | `uuid-ossp`                 |
| **Automação / CI**          | GitHub Actions (`cicd.yml`) |
| **Gerenciamento de Versão** | Git + GitHub                |

---

## 🧩 Estrutura do Projeto

```
script-postgresql-main/
├── LICENSE                     # Licença do projeto
├── script.sql                   # Script principal de criação e configuração do banco
└── .github/
    └── workflows/
        └── cicd.yml            # Pipeline CI/CD para execução e validação automática
```

---

## 🚀 Como Utilizar

### 💾 Pré-requisitos

* PostgreSQL instalado (versão 13 ou superior)
* Acesso ao terminal `psql` ou ferramenta de administração (como **pgAdmin**)

---

### ▶️ Executando o Script

1. Crie um novo banco de dados:

```sql
CREATE DATABASE bd2ano;
```

2. Conecte-se ao banco criado:

```bash
psql -U seu_usuario -d bd2ano
```

3. Execute o script SQL:

```bash
\i script.sql
```

Isso irá criar todas as tabelas, extensões e configurações necessárias automaticamente.

---

## 👩‍💻 Autor

**Iara Tech**

Projeto Interdisciplinar desenvolvido por alunos do 1º e 2º ano de ensino médio do Instituto J&F, com o propósito de facilitar o registro e consulta de ábacos industriais.

📍 São Paulo, Brasil
📧 [iaratech.oficial@gmail.com](mailto:iaratech.oficial@gmail.com)
🌐 GitHub: [https://github.com/IARA-TECH](https://github.com/IARA-TECH)
