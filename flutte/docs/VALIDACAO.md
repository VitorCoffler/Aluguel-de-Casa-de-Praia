# Validação da entrega

## Executado

Ambiente: Node.js v24.19.0.

`node --test backend/test/api.test.js`: **10 testes passaram, 0 falhas** (um teste principal com nove cenários).

Cenários efetivamente exercitados por HTTP e banco SQLite temporário:

1. Cadastro, hash de senha, login inválido, autenticação e rejeição de origem não autorizada.
2. Upload, criação de anúncio, filtros, proteção contra edição por outra conta e rejeição de arquivo de texto como foto.
3. Total calculado no servidor, validação de data impossível, capacidade, reserva da própria casa, preço divergente e privacidade.
4. Sobreposição de intervalos, checkout contíguo e duas requisições concorrentes para o mesmo período.
5. Bloqueios manuais, conflito com reserva e isolamento por proprietário.
6. Cancelamento, liberação de noites e preservação de histórico.
7. Edição e pausa de anúncio, restrição de novas reservas e preservação da diária contratada.
8. Código de recuperação de uso único e revogação de sessões após trocar senha.
9. Reinício da API com persistência de anúncios, fotos, reservas e sessões; revogação por logout.

Todos os 12 arquivos Dart também passaram por análise sintática com a gramática Dart do Tree-sitter, sem erros de parsing. Isso não substitui a análise de tipos do Dart/Flutter.

Também executados: verificação de sintaxe JavaScript (`node --check`) e do script Bash (`bash -n`).

## Não executado neste ambiente

Não há SDK Flutter/Dart instalado. Não foi possível executar `flutter pub get`, `flutter analyze`, `flutter test`, compilar ou visualizar a interface no navegador/emulador. Portanto, os testes da API não comprovam que o aplicativo Flutter foi compilado ou renderizado.

Os testes de intervalos em `app/test/reserva_test.dart` estão incluídos para execução local. O script PowerShell e os manifestos Android devem ser verificados no Windows/Flutter do usuário.

O pacote usa `table_calendar` 3.2.0 fixado para evitar a exigência de `intl >=0.20.3` da versão 3.3.0 em SDKs Flutter que ainda fixam `intl 0.20.2`. Não inclui lockfile gerado sem uma resolução real de dependências; preserve o `pubspec.lock` gerado no seu computador quando versionar o projeto.

## Verificação manual sugerida

- Executar o fluxo descrito no README com duas contas diferentes.
- Conferir catálogo, login, galeria e formulário em largura de celular e navegador.
- Selecionar uma saída no início de outro período ocupado: deve permitir checkout, sem reservar essa noite.
- Confirmar que um período não atravessa noites ocupadas no meio.
- Enviar e remover fotos; trocar a capa; editar e pausar anúncios.
- Reiniciar API e aplicativo e verificar dados e sessão.
- Confirmar recuperação local pelo código do terminal, sem presumir envio de e-mail.
