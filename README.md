# Casa da Praia · Portfólio

Evolução do projeto Flutter de Vitor Coffler Bianchi: catálogo de casas, hóspedes e anfitriões em uma mesma conta, calendário e reservas persistentes.

## O que está incluído

- Layout adaptativo: menu inferior em telas menores e menu lateral em telas largas.
- Catálogo com busca por nome/cidade, diária máxima e capacidade de hóspedes.
- Galeria de fotos com navegação, descrição e comodidades.
- Cadastro, login, logout com revogação de sessão e recuperação de senha configurável.
- Painel do anfitrião: criar, editar e pausar anúncios; enviar fotos; escolher a capa; bloquear e liberar períodos; consultar e cancelar reservas recebidas.
- Hóspede: selecionar entrada/saída, ajustar noites e hóspedes, conferir o total, confirmar e cancelar reservas próprias.
- Calendário com noites ocupadas e validação do período inteiro, inclusive das datas entre entrada e saída.
- API Node.js 24 + banco SQLite em disco. Sem necessidade de instalar um servidor de banco separado.
- Testes de integração da API com banco temporário real.

O app não precisa de pagamento, domínio nem conta em serviço externo para rodar localmente. Não há contas prontas nem senhas padrão: cadastre suas contas pela interface. O catálogo começa vazio para você usar suas próprias fotos e anúncios.

## 1. Iniciar o backend no Windows

Requisitos: Node.js **24.x** e Flutter instalado no PATH. O código usa `node:sqlite`, incluído no Node 24. Não exige dependências npm para executar a API.

Abra um terminal na pasta deste projeto:

```powershell
cd backend
Copy-Item .env.example .env
npm start
```

Deixe esse terminal aberto. A API fica em `http://localhost:4000`. O endpoint `http://localhost:4000/health` deve retornar `{"status":"ok"}`.

Na primeira inicialização, o banco e as tabelas são criados automaticamente em `backend/data/casa_da_praia.sqlite`. Fotos ficam em `backend/data/uploads`. Esses dados permanecem quando você fecha ou reinicia o servidor.

## 2. Preparar e executar o Flutter

Use esta nova pasta `app` para manter seu projeto entregue ao professor separado.

Em OUTRO terminal PowerShell, a partir da raiz do pacote:

```powershell
cd app
powershell -ExecutionPolicy Bypass -File .\preparar.ps1
flutter run -d chrome --web-port 5300 --dart-define=API_URL=http://localhost:4000
```

O comando `ExecutionPolicy Bypass` vale para esse processo de preparação, sem alterar a configuração global do Windows. Você pode ler o script antes de executá-lo. Ele gera as pastas Android/Web, configura acesso de rede Android para desenvolvimento e instala as dependências. Se o PowerShell for bloqueado por política da instituição, execute os passos Flutter manualmente e faça as mudanças de manifesto indicadas no script.

No Linux/macOS com Python 3, use `bash preparar.sh` dentro de `app`, seguido do mesmo comando `flutter run` para Chrome. O pacote foi preparado para Web e Android; não inclui configuração e validação de iOS ou desktop nativo.

**Não copie seu `test/widget_test.dart` antigo.** Ele pode esperar a classe `MyApp` ou o contador do template. O projeto agora usa `CasaDaPraiaApp` e possui testes próprios em `app/test/reserva_test.dart`.

Se preferir atualizar manualmente seu projeto existente, copie `app/lib`, `app/pubspec.yaml`, `app/analysis_options.yaml` e os testes novos. Mantenha uma cópia de segurança antes. A preparação em uma pasta nova é o caminho mais simples.

## 3. Experimentar os dois perfis

1. Entre em **Anfitrião → Entrar como anfitrião → Ainda não tenho conta**.
2. Cadastre seu nome, e-mail e uma senha de pelo menos 10 caracteres.
3. Em **Novo anúncio**, preencha casa, cidade, descrição, diária, capacidade, quartos e comodidades.
4. Envie de 1 a 10 fotos JPG, PNG ou WebP, cada uma com até 3 MB. Use fotos próprias ou com autorização. A primeira foto é a capa; o botão de estrela permite trocá-la.
5. Salve e volte a **Explorar**. A casa ficará no catálogo.
6. Saia e crie uma segunda conta para testar como hóspede. O dono não pode reservar sua própria casa.
7. Escolha as datas, confira o resumo e confirme. Abra **Minhas reservas**.
8. Retorne à conta do anfitrião para ver **Reservas recebidas** e testar bloqueios de datas.

Uma conta pode exercer os dois papéis. A permissão para editar uma casa depende do proprietário registrado no banco, não de um botão do aplicativo.

## Android

Para um emulador Android padrão:

```powershell
flutter run --dart-define=API_URL=http://10.0.2.2:4000
```

Selecione o dispositivo Android quando solicitado. Para celular físico, use o IP da máquina na mesma rede, ajuste `HOST=0.0.0.0` no `.env` e permita a porta 4000 no firewall somente na rede privada de desenvolvimento. Reinicie a API. Exemplo de parâmetro: `--dart-define=API_URL=http://192.168.1.20:4000` (substitua pelo seu IP).

O script permite HTTP apenas no manifesto de **debug**. Builds de produção devem usar API HTTPS. Não coloque `localhost` como endereço da API em um celular físico: ali ele aponta para o próprio celular.

## Recuperação de senha

Com `.env.example` copiado, `DEV_RESET_LOG=true` ativa **apenas desenvolvimento**: ao solicitar recuperação, o terminal da API mostra o código. Cole esse código na tela de recuperação. Esse modo não envia e-mail.

Para enviar e-mail de verdade, configure `RESET_WEBHOOK_URL` e `RESET_WEBHOOK_SECRET` para um serviço HTTPS sob seu controle que entregue o código ao endereço indicado. O servidor envia um POST autenticado contendo `email`, `token` e `expires_in_minutes`. Sem essa integração, o envio real de e-mail permanece pendente. Em produção (`NODE_ENV=production`), o log de código é desabilitado.

O código vale por 15 minutos, só pode ser usado uma vez e sua utilização revoga as sessões existentes. Não publique `.env`, tokens nem logs de recuperação.

## Regras de reserva

- De 1 a 90 noites, com datas nos próximos 730 dias.
- Datas da API no formato `AAAA-MM-DD`; o servidor considera o dia corrente em `America/Sao_Paulo`.
- O checkout não ocupa uma noite. Uma reserva de 10 a 13 ocupa as noites 10, 11 e 12; outra pode começar dia 13.
- O banco usa transação e gatilhos para impedir reservas/bloqueios sobrepostos, inclusive quando pedidos chegam juntos.
- O servidor calcula o total com a diária vigente. Se o preço mudou desde a abertura da tela, pede nova conferência.
- A diária e o total ficam gravados na reserva; alterações futuras no anúncio não mudam reservas existentes.
- Pausar um anúncio impede novas reservas, sem apagar o histórico.
- Cancelamento pelo hóspede ou dono é permitido até o dia da entrada. O histórico permanece com status cancelado.

## Verificação

```powershell
cd backend
npm test
```

Em outro terminal:

```powershell
cd app
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Veja `docs/VALIDACAO.md` para o que foi efetivamente executado durante a preparação do pacote e o que ainda precisa de verificação no seu Flutter.

## Estrutura

| Caminho | Responsabilidade |
| --- | --- |
| `app/lib/main.dart` | Tema, inicialização e navegação |
| `app/lib/models/reserva.dart` | Modelos, datas, dinheiro e intervalos |
| `app/lib/services/api.dart` | HTTP, sessão e armazenamento do token |
| `app/lib/screens/` | Catálogo, autenticação, detalhes, reservas e anfitrião |
| `app/lib/widgets/common.dart` | Componentes e estados reutilizáveis |
| `backend/src/server.js` | API, validação, autenticação e permissões |
| `backend/src/schema.sql` | Tabelas, índices e gatilhos |
| `backend/test/api.test.js` | Testes de integração |
| `docs/API.md` | Contrato da API |

## Limites desta versão

É uma base de portfólio para execução local, não uma operação comercial publicada. Não inclui pagamentos, confirmação de e-mail, mapas, chat, avaliações nem envio real de e-mail já contratado. Reservas são confirmadas sem cobrança. O endereço completo do imóvel não é coletado.

Antes de publicar: configure HTTPS, domínio/origens permitidas, serviço de e-mail, backups e limites de armazenamento; revise privacidade e políticas de cancelamento conforme seu uso. O token Web depende de contexto seguro (HTTPS ou localhost). Fotos removidas dos anúncios continuam no diretório de uploads; não há limpeza automática de arquivos órfãos nesta versão.

Para backup simples, desligue a API e copie **a pasta `backend/data` inteira**. Não publique essa pasta no GitHub. Para produção com múltiplas instâncias, planeje um banco e armazenamento de arquivos compartilhados; este pacote usa um servidor com volume persistente.

## Referências técnicas

- https://nodejs.org/docs/latest-v24.x/api/sqlite.html
- https://pub.dev/packages/table_calendar
- https://pub.dev/packages/http
- https://pub.dev/packages/flutter_secure_storage
- https://pub.dev/packages/file_picker
