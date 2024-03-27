# PowerShell Scripts Repository

## Description
Bem-vindo ao meu Repositório de Scripts PowerShell, uma coleção pessoal criada para agilizar e melhorar as tarefas de administração de sistemas. Cada script, nascido de desafios diários e insights, é personalizado para automatizar ou simplificar operações, aumentando significativamente a eficiência e reduzindo erros. Este repositório não é apenas um conjunto de ferramentas, mas um reflexo de experiência prática, projetado para empoderar outros administradores com soluções que foram testadas nas trincheiras da gestão de TI.

## Disclaimer
> [!IMPORTANT]
> **Aviso Importante:** Os scripts PowerShell dentro deste repositório são fornecidos "como estão", sem garantias. O uso desses scripts é inteiramente por sua conta e risco. É altamente recomendado testar cada script em um ambiente controlado e não produtivo antes de incorporá-los ao seu fluxo de trabalho regular. Este passo garante a compatibilidade e previne quaisquer consequências não intencionais em seus sistemas ou operações.

## Security Recommendation: Digital Signing of Scripts
> [!TIP]
>Para maior segurança e para garantir a integridade dos scripts dentro deste repositório, é altamente recomendado assinar digitalmente os scripts PowerShell antes do uso. A assinatura digital certifica a origem e confirma que o script não foi alterado ou comprometido desde que foi assinado. Esta prática ajuda a proteger seu ambiente contra a execução de scripts não autorizados ou maliciosos, alinhando-se às melhores práticas para gestão e implantação de scripts em ambientes de TI profissionais.

## Scripts
Aqui estão os scripts atualmente neste repositório:

### 1. Reboot Reminder
`RebootReminder.ps1` é um script PowerShell projetado para lembrar os usuários de reiniciar seu sistema se ele não tiver sido reiniciado dentro de um número especificado de dias. O script envia uma notificação de balão para o usuário, e se o sistema não for reiniciado dentro de um prazo especificado, ele força uma reinicialização do sistema. [Read more here](RebootReminder/README.md).

### 2. Show Balloon Tips
`ShowBalloonTips.ps1`é um script PowerShell projetado para exibir dicas de balão para o usuário. Este script pode ser usado para mostrar notificações, alertas ou lembretes para o usuário. [Read more here](ShowBalloonTips/README.md).

### 3. Find Empty Folders
`Find-EmptyFolders.ps1` é um script PowerShell robusto que identifica e registra todos os diretórios vazios dentro do caminho da pasta especificada. Ele também registra quaisquer erros encontrados e permite o controle da verbosidade do log. [Read more here](FindEmptyFolders/README.md).

### 4. Clear MS Teams Cache
`ClearTeamsCache.ps1` é um script PowerShell projetado para limpar o cache do Microsoft Teams e reiniciar o aplicativo. O script visa melhorar o desempenho do Microsoft Teams removendo pastas de cache específicas. Ele também realiza verificações de direitos administrativos, espaço em disco e conectividade de rede, e registra esses eventos. [Read more here](ClearTeamsCache/README.md).

### 5. Find Duplicate Files
`Find-DuplicateFiles.ps1` é um script PowerShell robusto voltado para identificar e tratar arquivos duplicados dentro de um diretório especificado. O script usa algoritmos de hash como MD5, SHA1 ou SHA256 para identificar duplicatas. Ele oferece uma gama de opções, como a exclusão de diretórios e tipos de arquivos específicos, confirmação do usuário para ação e mais. [Read more here](Find-DuplicateFiles/README.md).

### 6. Deployment Script
`DeploymentScript.ps1` é um script PowerShell versátil projetado para automatizar a implantação de software usando arquivos MSI em vários computadores remotos. Ele lida com várias tarefas administrativas, como verificar os pré-requisitos do sistema, validar conexões de rede, gerenciar credenciais de forma segura e registrar o processo de implantação. [Read more here](DeploymentScript/README.md).

### 7. USB Port and Storage Card Management Tool
`USBManagementTool.ps1` é um script PowerShell projetado para habilitar, desabilitar e monitorar o status do acesso a dispositivos de armazenamento USB e uso de cartão de armazenamento em sistemas Windows. Esta ferramenta fornece uma interface gráfica do usuário (GUI) para fácil interação e requer privilégios administrativos para operação. [Read more here](USBPortManagement/README.md).

## Usage
Cada script neste repositório é projetado para uso autônomo, adaptado a tarefas específicas de administração de sistemas. Para orientação detalhada sobre implantação e personalização, consulte os arquivos README que acompanham cada script. Estes documentos oferecem instruções passo a passo, garantindo que você possa aproveitar ao máximo o potencial de cada ferramenta de forma eficiente.

## Contribution
Recebemos com entusiasmo contribuições para enriquecer este repositório. Se você desenvolveu um script que pode beneficiar a comunidade de administração de sistemas, por favor, compartilhe conosco através de um pedido de pull. Pedimos que suas submissões incluam documentação abrangente, cobrindo uso, configuração e quaisquer pré-requisitos, para auxiliar outros na integração sem problemas de suas soluções.

## Author Note
> [!NOTE]
>Com curadoria cuidadosa de Cláudio Gonçalves, este repositório reflete um compromisso em compartilhar conhecimento e ferramentas que tornam o papel exigente de um administrador de sistemas um pouco mais fácil. Cada script é produto de experiência prática e tem a intenção de oferecer uma mão amiga aos colegas no campo de TI.
